#!/usr/bin/env perl
use strict;

# ----------------------------------------------------------------------------
# Copyright 2016 Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ----------------------------- END-OF-FILE ----------------------------------

#==============================================================================
# LIBRARIES
#------------------------------------------------------------------------------
use FindBin qw($Bin);
use lib "$FindBin::Bin/../lib/perl";

use Getopt::Long;
use File::Basename;
use Util::Message qw(fatal error warning alert verbose message debug);
use BDE::Util::Nomenclature qw(isComponent getComponentPackage);
$|=1;

#==============================================================================
# PARSE OPTIONS
#------------------------------------------------------------------------------
sub usage {
    print STDERR "!! @_\n" if @_;

    my $prog = basename $0;

    print STDERR<<_USAGE_END;

Usage: $prog -h | [-d] [-v] [-m] <-o htmlDir> [-b <baseTitle>]
   --help         | -h         Display usage information (this text)
   --debug        | -d         Enable debug reporting
   --verbose      | -v         Enable verbose reporting
   --userMainPage | -m         Main page supplied by user (elsewhere); do *not*
                               alias 'main.html' to 'components.html' (default)
   --htmlDir      | -o <htmlDir>
                               Output directory (home of Doxygenated files)
                                   default: ./html
   --baseTitle    | -b         Base HTML title
                                   default: "Bloomberg Development Environment"

_USAGE_END
}

#------------------------------------------------------------------------------
sub getOptions {
    my %opts;

    Getopt::Long::Configure("bundling", "no_ignore_case");
    unless (GetOptions(\%opts, qw[
        help|h|?
        debug|d+
        verbose|v+
        userMainPage|m+
        htmlDir|o=s
        baseTitle|b=s
    ])) {
        usage(), exit 1;
    }

    usage(), exit 0 if $opts{help};

    # debug mode
    Util::Message::set_debug($opts{debug} || 0);

    # verbose mode
    Util::Message::set_verbose($opts{verbose} || 0);

    # output directory
    $opts{htmlDir} ||= "html";

    # base title for HTML files
    $opts{baseTitle} ||= "Bloomberg Development Environment";

    return \%opts;
}

#==============================================================================
# HELPERS: Title Adjustments
#------------------------------------------------------------------------------
sub isDeprecated($$) {
    my $htmlDir  = shift;
    my $filename = shift;

    my $path = $htmlDir . "/" . $filename;
    open(FH2, "< $path") or fatal "!! cannot open $path for reading: $!";
    my @lines = <FH2>; close FH2; chomp @lines;

    my $pattern = "<dl class=\"deprecated\"><dt><b>"
                . "<a class=\"el\" href=\"deprecated.html#_deprecated.*\">"
                . "Deprecated:</a>";

    my @matches = grep /$pattern/, @lines;

    return scalar @matches;
}

sub isPrivateComponent($) {
    my $component = shift;

    isComponent $component or die "not component: $component";

    if ($component =~ s|^bslfwd_||) {
        my $ret = 1 if $component =~ m|buildtarget$|;
        $ret = $ret ? 1 : 0;
        return $ret;                                                   # RETURN
    }

   # return isSubordinateComponent $component; Workaround per DRQS 42208281.

    my $componentPackage =  getComponentPackage($component);
    my $componentStem    =  $component;
       $componentStem    =~ s/^$componentPackage\_//;

    return (scalar split /_/, $componentStem) > 1;
}

sub levelOfAggregation($)
{
    my $uor = shift;

    return $uor =~ m|^\w_\w+_\w+| ? "Component"     :
           $uor =~ m|^\w_\w+|     ? "Package"       :
           $uor =~ m|^\w+_\w+|    ? "Component"     :
           $uor =~ m|^\w{3}$|     ? "Package Group" :
           $uor =~ m|^\w{3}\w+$|  ? "Package"       :
                                    ""              ;
}

sub markupToAscii($)
{
    my $str = shift;
    $str =~ s|__|_|g;
    $str =~ s|_1|:|g;
    return $str;
}

sub classMembersTitle($)
{
    my $file = shift;
    $file =~ m|^class.*-members$| or fatal "bad pattern match on: " . $file;

    my $title = $file;
    $title =~ s|^class||;
    $title =~ s|-members$||;
    $title =  markupToAscii($title);
    $title = "Class " . $title . " Members";
    return $title;
}

sub classTitle($)
{
    my $file = shift;
    $file =~ m|^class.*| or fatal "bad pattern match on: " . $file;

    my $title = $file;
    $title =~ s|^class||;
    $title =  markupToAscii($title);
    $title = "Class " . $title;
    return $title;
}

sub groupTitle($)
{
    my $file = shift;
    $file =~ m|^group.*| or fatal "bad pattern match on: " . $file;

    my $title = $file;
    $title =~ s|^group__||;
    $title =  markupToAscii($title);
    $title =  $title . " " .  levelOfAggregation($title);
    return $title;
}

sub headerTitle($)
{
    my $file = shift;
    $file =~ m|_8h_source$| or fatal "bad pattern match on: " . $file;

    my $title = $file;
    $title =~ s|^class||;
    $title =~ s|_8h_source$|.h|;
    $title =  markupToAscii($title);
    $title =  $title . " Source";
    return $title;
}

sub fileReferenceTitle($)
{
    my $file = shift;
    $file =~ m|_8h$| or fatal "bad pattern match on: " . $file;
    my $title = $file;

    $title =~ s|^class||;
    $title =~ s|_8h$|.h|;
    $title =  markupToAscii($title);
    $title =  $title . " Reference";
    return $title;
}

sub structMembersTitle($)
{
    my $file = shift;
    $file =~ m|^struct.*-members$| or fatal "bad pattern match on: " . $file;

    my $title = $file;
    $title =~ s|^struct||;
    $title =~ s|-members$||;
    $title =  markupToAscii($title);
    $title = "Struct " . $title . " Members";
    return $title;
}

sub structTitle($)
{
    my $file = shift;
    $file =~ m|^struct.*| or fatal "bad pattern match on: " . $file;

    my $title = $file;
    $title =~ s|^struct||;
    $title =  markupToAscii($title);
    $title = "Struct " . $title;
    return $title;
}

sub namespaceTitle($)
{
    my $file = shift;
    $file =~ m|^namespace.*| or fatal "bad pattern match on: " . $file;

    my $title = $file;
    $title =~ s|^namespace||;
    $title =  markupToAscii($title);
    $title = "Namespace " . $title;
    return $title;
}

sub indexTitle($)
{
    my $file = shift;
    $file =~ m|^index.*| or fatal "bad pattern match on: " . $file;

    my $title = $file;
    $title =~ s|^index_||;
    $title =  markupToAscii($title);
    $title =  "Index of ".  $title . " " . levelOfAggregation($title);
    return $title;
}

sub unionMembersTitle($)
{
    my $file = shift;
    $file =~ m|^union.*-members$| or fatal "bad pattern match on: " . $file;

    my $title = $file;
    $title =~ s|^struct||;
    $title =~ s|-members$||;
    $title =  markupToAscii($title);
    $title = "Union " . $title . " Members";
    return $title;
}

sub unionTitle($)
{
    my $file = shift;
    $file =~ m|^union.*| or fatal "bad pattern match on: " . $file;

    my $title = $file;
    $title =~ s|^union||;
    $title =  markupToAscii($title);
    $title = "Union " . $title;
    return $title;
}

sub filenameToTitle($)
{
    my $file = shift;

    $file =~ '\.html$' or fatal "bad filename: " . $file;
    $file =~ s|\.html$||;

    return
        $file =~ m|^class.*-members$|  ?  classMembersTitle($file) :
        $file =~ m|^class.*|           ?         classTitle($file) :
        $file =~ m|^group.*|           ?         groupTitle($file) :
        $file =~ m|_8h_source$|        ?        headerTitle($file) :
        $file =~ m|_8h$|               ? fileReferenceTitle($file) :
        $file =~ m|^struct.*-members$| ? structMembersTitle($file) :
        $file =~ m|^struct.*|          ?        structTitle($file) :
        $file =~ m|^namespace.*|       ?     namespaceTitle($file) :
        $file =~ m|^index.*|           ?         indexTitle($file) :
        $file =~ m|^union.*-members$|  ?  unionMembersTitle($file) :
        $file =~ m|^union.*|           ?         unionTitle($file) :
                                                                "" ;
}

#==============================================================================
# HELPERS: HTML links
#------------------------------------------------------------------------------
sub composeLinkedAttributes($$)
{
    my $attributesAnchor   = shift;
    my $descriptionFileName = shift;

    return '<A  href="'
         . $descriptionFileName . '#' . $attributesAnchor
         . '">Attributes</A>';
}

sub composeLinkedDescription($$)
{
    my $descriptionAnchor   = shift;
    my $descriptionFileName = shift;

    return '<A  href="'
         . $descriptionFileName . '#' . $descriptionAnchor
         . '">@DESCRIPTION</A>';
}

sub extractAttributesAnchor($)
{
     my $content = shift;
     my $pattern = '.*\n<a href="#([^"]+)">Attributes </a> </li>\n.*';
     return undef if $content !~ m|$pattern|;
     return $1;
}

sub extractDescriptionAnchor($)
{
     my $content = shift;
     my $pattern = '.*\n<a href="#([^"]+)">Description </a> <ul>\n.*';
     return undef if $content !~ m|$pattern|;
     return $1;
}

sub descriptionFile($)
{
    my $file = shift;
    $file =~ s/^class/group__/;
    $file =~ s/_1_1/__/g;
    $file = lc $file;
    return $file;
}

sub needsAttributeLink($)
{
    my $contents = shift;
    my $pattern  = 'See the Attributes section under @DESCRIPTION'
                 . ' in the component-level documentation.';
    return $contents =~ m|$pattern|;
}

sub isClassFile($)
{
    my $file = shift;
    return 0 if $file !~ m|\.html$|;
    return 0 if $file !~ m|^class|;
    return 0 if $file =~ m|-members.html$|;
    return 1;
}

sub addAttributeLink($$$)
{
    my $content = shift;
    my $htmlDir = shift;
    my $file    = shift;

    my $descriptionFileName = descriptionFile($file);
    my $source              = "$htmlDir/$descriptionFileName";

    open(FH, "<", $source) or #fatal "cannot open $file: $!";
                               warn "A: cannot open $source: $!";
    my $descriptionFileContent = join '', <FH>;  #input entire file
    close(FH) or #fatal "cannot close: $file: $!";
                 warn "A: cannot close: $source: $!";

    my $descriptionAnchor = extractDescriptionAnchor($descriptionFileContent);
    my $attributesAnchor  = extractAttributesAnchor ($descriptionFileContent);

    my $linkedDescription = composeLinkedDescription($descriptionAnchor,
                                                     $descriptionFileName);
    my $linkedAttributes  = composeLinkedAttributes ($attributesAnchor,
                                                     $descriptionFileName);

    $content =~ s{See the Attributes section under} #sub only in context
                 {See the $linkedAttributes section under};

    $content =~ s{\@DESCRIPTION}{$linkedDescription}g;

    my $linkedGlossary =
              '<A href="group__bsldoc__glossary.html">bsldoc_glossary</A>';
    $content =~
        s{bsldoc_glossary}{$linkedGlossary}g;

    return $content;
}

#==============================================================================
# HELPERS: Component Links to Package Links
#------------------------------------------------------------------------------
sub isPackageGroupName($) {
    my $groupName =  shift;
    return $groupName =~ m|^(z_)?([el]_)?[a-z][a-z0-9]{2}$|;
}

sub isPkgGrpFile($)
{
    my $file = shift;
    return 0 if !isDoxygenGrpFile($file);

    $file =~ s/^group__//;
    $file =~ s/\.html$//;
    $file =~ s/__/_/g;
    my $retValue = isPackageGroupName($file);
    return $retValue;
}

sub changeComponentToPackageLinks($)
{
    my $content = shift;

    if ($content !~ m|\n<a href="#groups">Components</a>  </div>\n|) {
        verbose "changeComponentToPackageLinks: no match1";
    }

    $content =~ s{\n<a href="#groups">Components</a>  </div>\n}
                 {\n<a href="#groups">Packages</a>  </div>\n};

    if ($content !~ m|\nComponents</h2></td></tr>\n|) {
        verbose "changeComponentToPackageLinks: no match2";
    }

    $content =~ s{\nComponents</h2></td></tr>\n}
                 {\nPackages</h2></td></tr>\n};

    return $content;
}

sub isDoxygenGrpFile($)
{
    my $file = shift;
    return $file =~ m|^group__.*\.html$|;
}

sub removeBreaksFromTable($)
{
    my $content = shift;

    $content =~ s{\n<br/></td></tr>\n}
                 {\n</td></tr>\n}g;
    return $content;
}

#==============================================================================
# PROCESSING: '.html' files per drqs-38621330
#------------------------------------------------------------------------------

sub needsProcessingPerDrqs38621330($) {
    my $file = shift;
    return $file =~        m|\.html$|
       and $file !~ m|_source\.html$|;
}

sub editPerDrqs38621330($) {
    my $content = shift;

    my @lines    = split /\n/, $content;
    my @newLines = ();

    for my $line (@lines) {
        $line =~ s|\\\@|@|g if $line =~ m|<pre| .. $line =~ m|/pre>|;
        push @newLines, $line;
    }

    my $newContent =  join "\n", @newLines;
    $newContent .= "\n";

    return $newContent;
}

#==============================================================================
# MAJOR PROCESSING: '.html' files
#------------------------------------------------------------------------------

sub editHtmlFiles($$$)
{
    my $htmlDir         = shift;
    my $baseTitle       = shift;
    my $mainPageDefined = shift;

    verbose "editing HMTL files in $htmlDir";

    opendir(DIR, $htmlDir) or #fatal "cannot open directory: $htmlDir: $!";
                               warn "B: cannot open directory: $htmlDir: $!";

    my $fileCount = 0;

    while (my $file = readdir(DIR)) {
        if ($file !~     m|\.html$|
        or  $file =~ m|ORIG\.html$|) {
            verbose "SKIP file:|$file|";
            next;
        }
        verbose "PROC file:|$file|";

        open(FH, "< $htmlDir/$file") or #fatal "cannot open $file: $!";
                                         warn "C: cannot open $file: $!";
        my $content = join '', <FH>;  #input entire file
        close(FH) or fatal "cannot close: $file: $!";

        #optionally customize title of each page
        if ($baseTitle) {
            my $title =  filenameToTitle(basename($file));
            $title    =  $title ? "$baseTitle: $title" : "$baseTitle";
            $content  =~ s{<title>.*</title>}{<title>$title</title>}sg
        }

        $content =~
            s{<a class="qindex[^>]+>(Main|Alpha|Namespace).*?</a>\s+\|}{}sg;

        # Convert "module" (not a BDE term) to "component"
        $content =~ s{\bModule(s?)\b}{Component$1}sg;
        $content =~ s{\bmodule(s?)\b}{component$1}sg;
        $content =~ s{\bmain\.html\b}{components.html}sg if !$mainPageDefined;

        my $obscuredColonColon = "PER_DRQS-27494910_OBSCURE"
                               . "_COLON-COLON_HERE"
                               . "_THEN_RESTORE_IN_POST-PROCESSING";
        $content =~ s|${obscuredColonColon}|::|g;

        my $obscuredAsertiskSlash = "PER_DRQS-28777305_OBSCURE"
                                  . "_ASTERISK-SLASH_HERE"
                                  . "_THEN_RESTORE_IN_POST-PROCESSING";
        $content =~ s|${obscuredAsertiskSlash}|*/|g;

        if (isClassFile($file) and needsAttributeLink($content)) {
            $content = addAttributeLink($content, $htmlDir, $file);
        }

        if (isPkgGrpFile($file)) {
            $content = changeComponentToPackageLinks($content);
        }

        if (isDoxygenGrpFile($file)) {
            $content = removeBreaksFromTable($content);
        }

        if (needsProcessingPerDrqs38621330($file)) {
            $content = editPerDrqs38621330($content);
        }

        open(FH, "> $htmlDir/$file") or #fatal "cannot open $file: $!";
                                        warn "D: cannot open $file: $!";
        print FH $content;
        close(FH) or fatal "cannot close $file: $!";
        ++$fileCount;
    }
    closedir(DIR) or fatal "cannot closedir: $!";

    verbose "HTML file edit count: $fileCount";
    return $fileCount;
}

#==============================================================================
# MAJOR PROCESSING: 'doxygen.css'
#------------------------------------------------------------------------------
sub editDoxgenCss($)
{
    my $htmlDir = shift;

    verbose "editing 'doxygen.css' file in $htmlDir";

    # Edit 'doxygen.css' in the specified 'htmlDir' so that the specification
    # of borders in 'doxtable' is commented out.  The original file is
    # preserved in 'doxygen_ORIG.css' in the specified 'htmlDir'.

    my $old = $htmlDir . "/" . "doxygen.css";
    my $new = $htmlDir . "/" . "doxygen_ORIG.css";
    rename($old, $new) || fatal "rename: $old: $new: $!";

    my $cmd = <<'END';
sed '
/^table\.doxtable td, table\.doxtable th {$/,/^}$/{
    /border/{
        s|border|/* &|
        s|$| */|
    }
}'
END
    chomp $cmd;
    $cmd .= "<$new >$old\n";
    system "$cmd" || fatal "failed: $cmd: $!";
}

#==============================================================================
# MAJOR PROCESSING: 'deprecated.html'
#------------------------------------------------------------------------------

sub editDeprecatedFile($) {
    my $htmlDir = shift;

    my $path    = $htmlDir . "/" . "deprecated.html";
    if (open FH, "<" . $path) {
    } else {
        warn "editDeprecatedFile: SKIP: cannot open for read: $path: $!";
        return;
    }
    my @lines = <FH>; chomp @lines; close FH;

    for my $line (@lines) {
        if ($line =~ m|^<dt>Group |) {
              $line =~ m|\.html">(.*)<\a>|;
              my $item = $line;
              $item =~ s/.*\.html\">//;
              $item =~ s/<\/a>.*//;
              my $lOfA = levelOfAggregation($item);
              $line =~ s/Group/$lOfA/;
        }
    }

    open FH, ">" . $path  or
                  fatal "editDeprecatedFile: cannot open for writge: $path: $!";
    for my $line (@lines) {
        printf FH "%s\n", $line;
    }
    close FH;
}
#==============================================================================
# MAJOR PROCESSING: edit package- and package-group files
#------------------------------------------------------------------------------

sub editGroupFile($$$$) {
    my $htmlDir            = shift;
    my $filename           = shift;
    my $item               = shift;
    my $levelOfAggregation = shift;

    debug "editGroupFile: enter: $filename, $item, $levelOfAggregation";

    my $path = $htmlDir . "/" . $filename;
    verbose "editGroupFile: path: $path";

    open FH, "<" . $path  or
                        fatal "editGroupFile: cannot open for read: $path: $!";
    debug "editGroupFile: opened: $path";
    my @lines = <FH>; chomp @lines; close FH;
    debug "editGroupFile: read: $path";

    my @outlines = ();
    my $state    = 0;
    my       $isDeprecatedFlag = undef;
    my $isPrivateComponentFlag = undef;

    for my $line (@lines) {
        debug "$state: $line";

        $state = 1 if $line =~ m|^<table class=\"memberdecls\">$|;

        if (1 == $state) {
            if ($line =~ m|^<p><tr><td class=\"mdescLeft\"|) {

                # Reduce space round description lines.
                $line =~ s|(<td class=\"mdescRight\">)<p>|$1<p style="margin-top: 0; margin-bottom: 0;">|;
            }

            if ($line =~ m|^<tr><td class=\"memItemLeft\"|) {
                my $entityFile =  $line;
                   $entityFile =~ s/.*href="//;
                   $entityFile =~ s/">.*//;

                $isDeprecatedFlag = isDeprecated($htmlDir, $entityFile);

                my $entityField =  $line;
                   $entityField =~ s/.*\.html">//;
                   $entityField =~ s/<\/a>.*//;
                my @subFields = split / /, $entityField;
                my $numSubFields = scalar @subFields;

                my $entity = undef;
                if      (2 == $numSubFields) {
                    if ("Package"   ne $subFields[0]
                    and "Component" ne $subFields[0]) {
                       warn "editGroupFile: unexpected form: $subFields[0]";
                    }
                    $entity = $subFields[1];
                } elsif (1 == $numSubFields) {
                    warn "editGroupFile: unexpected form: $entityField";
                    warn "editGroupFile: missing '.txt' file?";
                    $entity = lc $subFields[0]; # Synthetic entity may have
                                                # lead capital letter.
                    warn "editGroupFile: assume entity is: $entity";
                } else {
                    fatal
                      "editGroupFile: totally unexpected syntax: $entityField";
                }

                debug "editGroupFile: entity: $entity";

                $isPrivateComponentFlag =         (isComponent $entity)
                                        && (isPrivateComponent $entity);

                if ($isDeprecatedFlag) {
                    $line =~ s|(</a>)|<strong>: DEPRECATED</strong>$1|
                }

                if ($isPrivateComponentFlag) {
                    $line =~ s|(<\/a>)|<strong>: PRIVATE</strong>$1|
                }

                if ($isDeprecatedFlag || $isPrivateComponentFlag) {
                    #$line =~ s|(<tr>)|$1<span style="color:gray;">|;
                    #$line =~ s|(<\/tr>)|<\/span>$1|;

                    #$line =~ s|<tr>|<tr style="color:gray;">|;
                    #$line =~ s|<tr>|<tr style="background-color:gray;">|;

                    $line =~ s|(\.html">)|$1<span style="color:gray;">|;
                    $line =~ s|(<\/a>)|</span>$1|;
                }

                debug "$isDeprecatedFlag, $isPrivateComponentFlag: $line\n";
            }
            if ($line =~ m|^<p><tr><td class=\"mdescLeft\"|) {
                if ($isDeprecatedFlag || $isPrivateComponentFlag) {
                    $line =~ s|(<p style=")|$1color: gray;|;
                   # $line =~ s|(<\/p>)|</span>$1|;
                }
            }
        }

        $state = 0 if $line =~ m|^<\/table>$|;

        push @outlines, $line;
    }

    $path    = $htmlDir . "/" . $filename;
    open FH, ">" . $path  or
                       fatal "editGroupFile: cannot open for write: $path: $!";
    for my $line (@outlines) {
        print FH "$line\n";
    }

    debug "editGroupFile: leave: $filename, $item, $levelOfAggregation";
}

sub editGroupFiles($) {
    my $htmlDir = shift;

    debug "editGroupFiles: enter: editGroupFiles: $htmlDir";

    my @filenames = glob  "$htmlDir/group__*.html";

    map {debug "editGroupsFiles: todo: $_"; } @filenames;

    for my $filename (@filenames) {
        $filename = basename $filename;
        my $item =  $filename;
           $item =~ s/^group__//;
           $item =~ s/\.html$//;
           $item = markupToAscii      $item;
        my $lOfA = levelOfAggregation $item;
        if ("Component" ne $lOfA) {
            editGroupFile $htmlDir, $filename, $item, $lOfA;
        }
    }

    debug "editGroupFiles: leave: editGroupFiles: $htmlDir";
}

#==============================================================================
# MAIN
#------------------------------------------------------------------------------
MAIN: {
    my $prog            = basename $0;
    my $opts            = getOptions();
    my $htmlDir         = $opts->{htmlDir}; $htmlDir or
                                            fatal "$prog: no output directory";
    my $baseTitle       = $opts->{baseTitle};
    my $mainPageDefined = $opts->{userMainPage};

    verbose "DO: editHtmlFiles";
    editHtmlFiles($htmlDir, $baseTitle, $mainPageDefined);

    verbose "DO: editDoxgenCss";
    editDoxgenCss($htmlDir);

    verbose "DO: editDeprecatedFile";
    editDeprecatedFile($htmlDir);

    verbose "DO: editGroupFiles";
    editGroupFiles($htmlDir);

# Creates one index file per group; however, they are never referenced.
#
#    logmsg "-- processing index files for ".join(", ",@groups);
#    for my $g (@groups) {
#        open(INDEX,"< ./index.html") or die "Cannot read index.html!";
#        open(GINDEX,"> ./index_$g.html") or
#                                      die "Cannot write index_$g.html!";
#        my $doxy_g = $g;
#        $doxy_g =~ s/_/__/g; # doxygen turns _ into __ so mimic it
#        while (<INDEX>) {
#            s!components!group__$doxy_g!go;
#            print GINDEX $_;
#        }
#        close(INDEX) or fatal "cannot close index.html: $!";
#        close(GINDEX) or fatal "cannot close index_$g.html: $!";
#    }
#--
    exit 0;
}
