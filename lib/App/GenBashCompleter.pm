package App::GenBashCompleter;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::Any '$log';

use Monkey::Patch::Action;

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => "Generate completion scripts",
};

# XXX plugin based
sub _detect_file {
    my ($prog, $path) = @_;
    open my($fh), "<", $path or return [500, "Can't open: $!"];
    read $fh, my($buf), 2;
    my $is_script = $buf eq '#!';

    # currently we don't support non-scripts at all
    return [200, "OK", 0, {"func.reason"=>"Not a script"}] if !$is_script;

    my $is_perl_script = <$fh> =~ /perl/;
    seek $fh, 0, 0;
    my $content = do { local $/; ~~<$fh> };

    my $qprog = shell_quote($prog);
    if ($content =~
            /^\s*# FRAGMENT id=bash-completion-prog-hints command=(.+?)\s*$/m) {
        return [200, "OK", 1, {
            "func.command"=>"complete -C ".shell_quote($1)." $qprog",
            "func.note"=>"hint",
        }];
    } elsif ($content =~
            /^\s*# FRAGMENT id=bash-completion-prog-hints completer=1 for=(.+?)\s*$/m) {
        return [200, "OK", 1, {
            "func.command"=>join(
                "; ",
                map {"complete -C $qprog ".shell_quote($_)} split(',',$1)
            ),
            "func.note"=>"hint(completer)",
        }];
    } elsif ($is_perl_script && $content =~
                 /^\s*(use|require)\s+(Perinci::CmdLine(?:::Any|::Lite)?)\b/m) {
        return [200, "OK", 1, {
            "func.command"=>"complete -C $qprog $qprog",
            "func.note"=>$2,
        }];
    } elsif ($is_perl_script && $content =~
                 /^\s*(use|require)\s+(Getopt::Long::Complete)\b/m) {
        return [200, "OK", 1, {
            "func.command"=>"complete -C $qprog $qprog",
            "func.note"=>$2,
        }];
    }
    [200, "OK", 0];
}

# add one or more programs
sub _add {
    my %args = @_;

    my $readres = _read_parse_f($args{file});
    return err("Can't read entries", $readres) if $readres->[0] != 200;

    my %existing_progs = map {$_->{id}=>1} @{ $readres->[2]{parsed} };

    my $content = $readres->[2]{content};

    my $added;
    my $envres = envresmulti();
  PROG:
    for my $prog0 (@{ $args{progs} }) {
        my $path;
        $log->infof("Processing program %s ...", $prog0);
        if ($prog0 =~ m!/!) {
            $path = $prog0;
            unless (-f $path) {
                $log->errorf("No such file '$path', skipped");
                $envres->add_result(404, "No such file", {item_id=>$prog0});
                next PROG;
            }
        } else {
            $path = which($prog0);
            unless ($path) {
                $log->errorf("'%s' not found in PATH, skipped", $prog0);
                $envres->add_result(404, "Not in PATH", {item_id=>$prog0});
                next PROG;
            }
        }
        my $prog = $prog0; $prog =~ s!.+/!!;
        my $detectres = _detect_file($prog, $path);
        if ($detectres->[0] != 200) {
            $log->errorf("Can't detect '%s': %s", $prog, $detectres->[1]);
            $envres->add_result($detectres->[0], $detectres->[1],
                                {item_id=>$prog0});
            next PROG;
        }
        $log->debugf("Detection result %s: %s", $prog, $detectres);
        if (!$detectres->[2]) {
            # we simply ignore undetected programs
            next PROG;
        }

        if ($args{replace}) {
            if ($existing_progs{$prog}) {
                $log->infof("Replacing entry in %s: %s",
                            $readres->[2]{path}, $prog);
            } else {
                $log->infof("Adding entry to %s: %s",
                            $readres->[2]{path}, $prog);
            }
        } else {
            if ($existing_progs{$prog}) {
                $log->debugf("Entry already exists in %s: %s, skipped",
                             $readres->[2]{path}, $prog);
                next PROG;
            } else {
                $log->infof("Adding entry to %s: %s",
                            $readres->[2]{path}, $prog);
            }
        }

        my $insres = Text::Fragment::insert_fragment(
            text=>$content, id=>$prog,
            payload=>$detectres->[3]{'func.command'},
            ((attrs=>{note=>$detectres->[3]{'func.note'}}) x !!$detectres->[3]{'func.note'}));
        $envres->add_result($insres->[0], $insres->[1],
                            {item_id=>$prog0});
        next if $insres->[0] == 304;
        next unless $insres->[0] == 200;
        $added++;
        $content = $insres->[2]{text};
    }

    if ($added) {
        my $writeres = _write_f($args{file}, $content);
        return err("Can't write", $writeres) if $writeres->[0] != 200;
    }

    $envres->as_struct;
}

1;
# ABSTRACT: Backend for gen-bash-completer
