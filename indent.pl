#!/usr/bin/perl
#	This program is free software: you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation, either version 3 of the License, or
#	(at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	See http://www.gnu.org/licenses/.
#
#	For details of how to use this file, please see readme.txt

# load packages/modules
use strict;
use warnings;           
use FindBin;            # help find defaultSettings.yaml 
use YAML::Tiny;         # interpret defaultSettings.yaml
use File::Copy;         # to copy the original file to backup (if overwrite option set)
use File::Basename;     # to get the filename and directory path
use Getopt::Std;        # to get the switches/options/flags
use POSIX qw/strftime/; # date and time
use File::HomeDir;      # to get users home directory, regardless of OS

# get the options
my %options=();
getopts("sotlw", \%options);

# Check the number of input arguments- if it is 0 then simply 
# display the list of options (like a manual)
if(scalar(@ARGV) < 1)
{
    print <<ENDQUOTE
usage: indent.plx [options] [file][.tex]
      -o  output to another file
      -w  overwrite the current file- a backup will be made, but still be careful
      -s  silent mode- no output will be given to the terminal
      -t  tracing mode- verbose information given to the log file
      -l  use localSettings.yaml (assuming it exists in the directory of your file)
ENDQUOTE
    ;
    exit(2);
}

# setup variables from the flags
my $overwrite = $options{w};
my $outputToFile = $options{o};
my $silentMode = $options{s};
my $tracingMode = $options{t};
my $readLocalSettings = $options{l};

# we'll be outputting to the logfile and to standard output
my $logfile;
my $out = *STDOUT;

# open the log file
open($logfile,">","indent.log") or die "Can't open indent.log";

print $logfile strftime "%F %T", localtime $^T;
print $logfile <<ENDQUOTE

indent.plx version 8.0, a script to indent .tex files

file: $ARGV[0]
ENDQUOTE
;

# a quick options check
if($outputToFile and $overwrite)
{
    print $logfile <<ENDQUOTE 

WARNING: 
\t You have called indent.plx with both -o and -w
\t -o (output to file) will take priority, and -w (over write) will be ignored
 
ENDQUOTE
;
    $overwrite = 0;
}

# can't call the script with MORE THAN 2 files
if(scalar(@ARGV)>2)
{
    for my $fh ($out,$logfile) {print $fh <<ENDQUOTE

ERROR:
\t You're calling indent.plx with more than two file names
\t The script can take at MOST two file names, but you 
\t need to call it with the -o switch; for example

\t indent.plx -o originalfile.tex outputfile.tex

No indentation done :(
Exiting...
ENDQUOTE
    };
    exit(2);
}

# don't call the script with 2 files unless the -o flag is active
if(!$outputToFile and scalar(@ARGV)==2)
{
for my $fh ($out,$logfile) {
print $fh <<ENDQUOTE

ERROR:
\t You're calling indent.plx with two file names, but not the -o flag.
\t Did you mean to use the -o flag ?

No indentation done :(
Exiting...
ENDQUOTE
};
    exit(2);
}

# if the script is called with the -o switch, then check that 
# a second file is present in the call, e.g
#           indent.plx -o myfile.tex output.tex
if($outputToFile and scalar(@ARGV)==1)
{
    for my $fh ($out,$logfile) {print $fh <<ENDQUOTE
ERROR: When using the -o flag you need to call indent.plx with 2 arguments

indent.plx -o "$ARGV[0]" [needs another name here]

No indentation done :(
Exiting...
ENDQUOTE
};
    exit(2);
}

# Create a YAML file
my $defaultSettings = YAML::Tiny->new;

# Open defaultSettings.yaml
$defaultSettings = YAML::Tiny->read( "$FindBin::Bin/defaultSettings.yaml" );

# setup the DEFAULT variables and hashes from the YAML file

# scalar variables
my $defaultIndent = $defaultSettings->[0]->{defaultIndent};
my $alwaysLookforSplitBraces = $defaultSettings->[0]->{alwaysLookforSplitBraces};
my $alwaysLookforSplitBrackets = $defaultSettings->[0]->{alwaysLookforSplitBrackets};
my $backupExtension = $defaultSettings->[0]->{backupExtension};
my $indentPreamble = $defaultSettings->[0]->{indentPreamble};
my $onlyOneBackUp = $defaultSettings->[0]->{onlyOneBackUp};
my $indentAfterDocument = $defaultSettings->[0]->{indentAfterDocument};

# hash variables
my %lookForAlignDelims= %{$defaultSettings->[0]->{lookForAlignDelims}};
my %indentRules= %{$defaultSettings->[0]->{indentRules}};
my %verbatimEnvironments= %{$defaultSettings->[0]->{verbatimEnvironments}};
my %noIndentBlock= %{$defaultSettings->[0]->{noIndentBlock}};
my %checkunmatched= %{$defaultSettings->[0]->{checkunmatched}};
my %checkunmatchedELSE= %{$defaultSettings->[0]->{checkunmatchedELSE}};
my %checkunmatchedbracket= %{$defaultSettings->[0]->{checkunmatchedbracket}};
my %noAdditionalIndent= %{$defaultSettings->[0]->{noAdditionalIndent}};

# need new hashes to store the user and local data before
# overwriting the default
my %lookForAlignDelimsUSER;
my %indentRulesUSER;
my %verbatimEnvironmentsUSER;
my %noIndentBlockUSER;
my %checkunmatchedUSER;
my %checkunmatchedELSEUSER;
my %checkunmatchedbracketUSER;
my %noAdditionalIndentUSER;

# get information about user settings- first check if indentconfig.yaml exists
my $indentconfig = File::HomeDir->my_home . "/indentconfig.yaml";
if ( -e $indentconfig ) 
{
      print $logfile "Reading path information from ",File::HomeDir->my_home,"/indentconfig.yaml\n\n";

      # read the absolute paths from indentconfig.yaml
      my $userSettings = YAML::Tiny->read( "$indentconfig" );
      my @absPaths = @{$userSettings->[0]->{paths}};

      # read in the settings from each file
      foreach my $settings (@absPaths)
      {
        # check that the settings file exists
        if (-e $settings)
        {
            print $logfile "Reading user settings from $settings\n";
            $userSettings = YAML::Tiny->read( "$settings" );

            # scalar variables
            $defaultIndent = $userSettings->[0]->{defaultIndent} if defined($userSettings->[0]->{defaultIndent});
            $alwaysLookforSplitBraces = $userSettings->[0]->{alwaysLookforSplitBraces} if defined($userSettings->[0]->{alwaysLookforSplitBraces});
            $alwaysLookforSplitBrackets = $userSettings->[0]->{alwaysLookforSplitBrackets} if defined($userSettings->[0]->{alwaysLookforSplitBrackets});
            $backupExtension = $userSettings->[0]->{backupExtension} if defined($userSettings->[0]->{backupExtension});
            $indentPreamble = $userSettings->[0]->{indentPreamble} if defined($userSettings->[0]->{indentPreamble});
            $onlyOneBackUp = $userSettings->[0]->{onlyOneBackUp} if defined($userSettings->[0]->{onlyOneBackUp});
            $indentAfterDocument = $userSettings->[0]->{indentAfterDocument} if defined($userSettings->[0]->{indentAfterDocument});

            # hash variables - note that each one requires two lines, 
            # one to read in the data, one to put the keys&values in correctly

            %lookForAlignDelimsUSER= %{$userSettings->[0]->{lookForAlignDelims}} if defined($userSettings->[0]->{lookForAlignDelims});
            @lookForAlignDelims{ keys %lookForAlignDelimsUSER } = values %lookForAlignDelimsUSER if (%lookForAlignDelimsUSER);

            %indentRulesUSER= %{$userSettings->[0]->{indentRules}} if defined($userSettings->[0]->{indentRules});
            @indentRules{ keys %indentRulesUSER } = values %indentRulesUSER if (%indentRulesUSER);

            %verbatimEnvironmentsUSER= %{$userSettings->[0]->{verbatimEnvironments}} if defined($userSettings->[0]->{verbatimEnvironments});
            @verbatimEnvironments{ keys %verbatimEnvironmentsUSER } = values %verbatimEnvironmentsUSER if (%verbatimEnvironmentsUSER);

            %noIndentBlockUSER= %{$userSettings->[0]->{noIndentBlock}} if defined($userSettings->[0]->{noIndentBlock});
            @noIndentBlock{ keys %noIndentBlockUSER } = values %noIndentBlockUSER if (%noIndentBlockUSER);

            %checkunmatchedUSER= %{$userSettings->[0]->{checkunmatched}} if defined($userSettings->[0]->{checkunmatched});
            @checkunmatched{ keys %checkunmatchedUSER } = values %checkunmatchedUSER if (%checkunmatchedUSER);

            %checkunmatchedbracketUSER= %{$userSettings->[0]->{checkunmatchedbracket}} if defined($userSettings->[0]->{checkunmatchedbracket});
            @checkunmatchedbracket{ keys %checkunmatchedbracketUSER } = values %checkunmatchedbracketUSER if (%checkunmatchedbracketUSER);

            %noAdditionalIndentUSER= %{$userSettings->[0]->{noAdditionalIndent}} if defined($userSettings->[0]->{noAdditionalIndent});
            @noAdditionalIndent{ keys %noAdditionalIndentUSER } = values %noAdditionalIndentUSER if (%noAdditionalIndentUSER);

        }
        else
        {
            # otherwise keep going, but put a warning in the log file
            print $logfile "\nWARNING\n\t",File::HomeDir->my_home,"/indentconfig.yaml\n";
            print $logfile "\tspecifies $settings \n\tbut this file does not exist- unable to read settings from this file\n\n"
        }
      }
} 

# get information about LOCAL settings, assuming that localSettings.yaml exists
my $directoryName = dirname $ARGV[0];
if ( (-e "$directoryName/localSettings.yaml") and $readLocalSettings) 
{
      print $logfile "Reading LOCAL settings from $directoryName/localSettings.yaml\n";

      my $localSettings = YAML::Tiny->read( "$directoryName/localSettings.yaml" );

      # scalar variables
      $defaultIndent = $localSettings->[0]->{defaultIndent} if defined($localSettings->[0]->{defaultIndent});
      $alwaysLookforSplitBraces = $localSettings->[0]->{alwaysLookforSplitBraces} if defined($localSettings->[0]->{alwaysLookforSplitBraces});
      $alwaysLookforSplitBrackets = $localSettings->[0]->{alwaysLookforSplitBrackets} if defined($localSettings->[0]->{alwaysLookforSplitBrackets});
      $backupExtension = $localSettings->[0]->{backupExtension} if defined($localSettings->[0]->{backupExtension});
      $indentPreamble = $localSettings->[0]->{indentPreamble} if defined($localSettings->[0]->{indentPreamble});
      $onlyOneBackUp = $localSettings->[0]->{onlyOneBackUp} if defined($localSettings->[0]->{onlyOneBackUp});
      $indentAfterDocument = $localSettings->[0]->{indentAfterDocument} if defined($localSettings->[0]->{indentAfterDocument});

      # hash variables - note that each one requires two lines, 
      # one to read in the data, one to put the keys&values in correctly

      %lookForAlignDelimsUSER= %{$localSettings->[0]->{lookForAlignDelims}} if defined($localSettings->[0]->{lookForAlignDelims});
      @lookForAlignDelims{ keys %lookForAlignDelimsUSER } = values %lookForAlignDelimsUSER if (%lookForAlignDelimsUSER);

      %indentRulesUSER= %{$localSettings->[0]->{indentRules}} if defined($localSettings->[0]->{indentRules});
      @indentRules{ keys %indentRulesUSER } = values %indentRulesUSER if (%indentRulesUSER);

      %verbatimEnvironmentsUSER= %{$localSettings->[0]->{verbatimEnvironments}} if defined($localSettings->[0]->{verbatimEnvironments});
      @verbatimEnvironments{ keys %verbatimEnvironmentsUSER } = values %verbatimEnvironmentsUSER if (%verbatimEnvironmentsUSER);

      %noIndentBlockUSER= %{$localSettings->[0]->{noIndentBlock}} if defined($localSettings->[0]->{noIndentBlock});
      @noIndentBlock{ keys %noIndentBlockUSER } = values %noIndentBlockUSER if (%noIndentBlockUSER);

      %checkunmatchedUSER= %{$localSettings->[0]->{checkunmatched}} if defined($localSettings->[0]->{checkunmatched});
      @checkunmatched{ keys %checkunmatchedUSER } = values %checkunmatchedUSER if (%checkunmatchedUSER);

      %checkunmatchedbracketUSER= %{$localSettings->[0]->{checkunmatchedbracket}} if defined($localSettings->[0]->{checkunmatchedbracket});
      @checkunmatchedbracket{ keys %checkunmatchedbracketUSER } = values %checkunmatchedbracketUSER if (%checkunmatchedbracketUSER);

      %noAdditionalIndentUSER= %{$localSettings->[0]->{noAdditionalIndent}} if defined($localSettings->[0]->{noAdditionalIndent});
      @noAdditionalIndent{ keys %noAdditionalIndentUSER } = values %noAdditionalIndentUSER if (%noAdditionalIndentUSER);
} 
elsif ( !(-e "$directoryName/localSettings.yaml") and $readLocalSettings) 
{
      print $logfile "WARNING\n\t$directoryName/localSettings.yaml not found\n";
      print $logfile "\tcarrying on without it.\n";
} 

# if we want to over write the current file
# create a backup first
if ($overwrite)
{
    print $logfile "\nBackup procedure:\n";
    # original name of file
    my $filename = $ARGV[0];
    # copy it
    my $backupFile = $filename;
    
    # if onlyOneBackUp is set, then the backup file will
    # be overwritten each time
    if($onlyOneBackUp)
    {
        $backupFile =~ s/\.tex/$backupExtension/;
        print $logfile "\t copying $filename to $backupFile\n";
        print $logfile "\t $backupFile was overwritten\n\n" if (-e $backupFile);
    }
    else
    {
        # start with a backup file .bak0 (or whatever $backupExtension is present)
        my $backupCounter = 0;
        $backupFile =~ s/\.tex$/$backupExtension$backupCounter/;

        # if it exists, then keep going: .bak0, .bak1, ...
        while (-e $backupFile)
        {
            print $logfile "\t $backupFile already exists, incrementing by 1...\n";
            $backupCounter++;
            $backupFile =~ s/$backupExtension.*/$backupExtension$backupCounter/;
        }
        print $logfile "\n\t copying $filename to $backupFile\n\n";
    }

    # output these lines to the log file
    print $logfile "\t Backup file: ",$backupFile,"\n";
    print $logfile "\t Overwriting file: ",$filename,"\n\n";
    copy($filename,$backupFile) or die "Could not write to backup file $backupFile. Please check permissions. Exiting.\n";
}

if(!($outputToFile or $overwrite)) 
{
    print $logfile "Just out put to the terminal :)\n\n" if !$silentMode  ;
}

# scalar variables
my $line='';                # $line: takes the $line of the file
my $inpreamble=!$indentPreamble;
                            # $inpreamble: switch to determine if in
                            #               preamble or not
my $inverbatim=0;           # $inverbatim: switch to determine if in
                            #               a verbatim environment or not
my $delimiters=0;           # $delimiters: switch that governs if
                            #              we need to check for & or not
my $matchedbraces=0;        # $matchedbraces: counter to see if { }
                            #               are matched; it will be 
                            #               positive if too many { 
                            #               negative if too many }
                            #               0 if matched
my $matchedBRACKETS=0;      # $matchedBRACKETS: counter to see if [ ]
                            #               are matched; it will be 
                            #               positive if too many { 
                            #               negative if too many }
                            #               0 if matched
my $commandname='';         # $commandname: either \parbox, \marginpar,
                            #               or anything else from %checkunmatched
my $commanddetails = '';    # $command details: a scalar that stores
                            #               details about the command 
                            #               that splits {} across lines
my $countzeros = '';        # $countzeros:  a counter that helps 
                            #               when determining if we're in
                            #               an else construct
my $lookforelse=0;          # $lookforelse: a boolean to help determine 
                            #               if we need to look for an 
                            #               else construct
my $trailingcomments='';    # $trailingcomments stores the comments at the end of 
                            #           a line 
my $lineCounter=0;          # $lineCounter keeps track of the line number

# array variables
my @indent=();              # @indent: stores current level of indentation
my @lines=();               # @lines: stores the newly indented lines
my @block=();               # @block: stores blocks that have & delimiters
my @commandstore=();        # @commandstore: stores commands that 
                            #           have split {} across lines
my @commandstorebrackets=();# @commandstorebrackets: stores commands that 
                            #           have split [] across lines
my @mainfile=();            # @mainfile: stores input file; used to 
                            #            grep for \documentclass

# check to see if the current file has \documentclass, if so, then 
# it's the main file, if not, then it doesn't have preamble
open(MAINFILE, $ARGV[0]) or die "Could not open input file";
    @mainfile=<MAINFILE>;
close(MAINFILE);

# if the MAINFILE doesn't have a \documentclass statement, then 
# it shouldn't have preamble
if(scalar(@{[grep(m/^\s*\\documentclass/, @mainfile)]})==0)
{
    $inpreamble=0;

    print $logfile "Trace:\tNo documentclass detected, assuming no preamble\n" if($tracingMode);
}
else
{
    print $logfile "Trace:\t documentclass detected, assuming preamble\n" if($tracingMode);
}

# the previous OPEN command puts us at the END of the file
open(MAINFILE, $ARGV[0]) or die "Could not open input file";

# loop through the lines in the INPUT file
while(<MAINFILE>)
{
    # increment the line counter
    $lineCounter++;
    
    # tracing mode
    print $logfile "\n" if($tracingMode and !($inpreamble or $inverbatim));

    # check to see if we're still in the preamble
    # or in a verbatim environment
    if(!($inpreamble or $inverbatim))
    {
        # if not, remove all leading spaces and tabs
        # from the current line
        s/^\ *//; 
        s/^\t*//; 

        # tracing mode
        print $logfile "Line $lineCounter\t removing leading spaces\n" if($tracingMode);
    }
    else
    {
        # otherwise check to see if we've reached the main
        # part of the document
        if(m/^\s*\\begin{document}/)
        {
            $inpreamble = 0;

            # tracing mode
            print $logfile "Line $lineCounter\t \\begin{document} found \n" if($tracingMode);
        }
        else
        {
            # tracing mode
            if($inpreamble)
            {
                print $logfile "Line $lineCounter\t still in preamble, doing nothing\n" if($tracingMode);
            }
            elsif($inverbatim)
            {
                print $logfile "Line $lineCounter\t in verbatim-like environment, doing nothing\n" if($tracingMode);
            }
        }
    }

    # check to see if we have \end{something} or \]
    &at_end_of_env_or_eq() if(!$inpreamble);

    # check to see if we're at the end of a noindent 
    # block %\end{noindent}
    &at_end_noindent();

    # only check for unmatched braces if we're not in
    # a verbatim-like environment or in the preamble
    if(!($inverbatim or $inpreamble))
    {
        # The check for closing } and ] relies on counting, so 
        # we have to remove trailing comments so that any {, }, [, ]
        # that are found after % are not counted
        #
        # note that these lines are NOT in @lines, so we
        # have to store the $trailingcomments to put
        # back on after the counting
        #
        # note the use of (?<!\\)% so that we don't match \%
        if ( $_=~ m/(?<!\\)%.*/)
        {
            s/((?<!\\)%.*)//;
            $trailingcomments=$1;

            # tracing mode
            print $logfile "Line $lineCounter\t Removed trailing comments to count braces and brackets: $1\n" if($tracingMode);
        }

        # check to see if we're at the end of a \parbox, \marginpar
        # or other split-across-lines command and check that
        # we're not starting another command that has split braces (nesting)
        &end_command_or_key_unmatched_braces();

        # check to see if we're at the end of a command that splits 
        # [ ] across lines
        &end_command_or_key_unmatched_brackets();

        # add the trailing comments back to the end of the line
        if(scalar($trailingcomments))
        {
            # some line break magic, http://stackoverflow.com/questions/881779/neatest-way-to-remove-linebreaks-in-perl
            s/\R//;
            $_ = $_ . $trailingcomments."\n" ;

            # tracing mode
            print $logfile "Line $lineCounter\t counting braces/brackets complete: added trailing comments back on $trailingcomments\n" if($tracingMode);

            # empty the trailingcomments
            $trailingcomments='';

        }
    }

    # ADD CURRENT LEVEL OF INDENTATION
    # (unless we're in a delimiter-aligned block)
    if(!$delimiters)
    {
        # make sure we're not in a verbatim block or in the preamble
        if($inverbatim or $inpreamble)
        {
           # just push the current line as is
           push(@lines,$_);
        }
        else
        {
            # add current value of indentation to the current line
            # and output it
            $_ = join("",@indent).$_;
            push(@lines,$_);
            # tracing mode
            print $logfile "Line $lineCounter\t Adding current level of indentation\n" if($tracingMode);
        }
    }
    else
    {
        # output to @block if we're in a delimiter block
        push(@block,$_);

        # tracing mode
        print $logfile "Line $lineCounter\t In delimeter block, waiting for block formatting\n" if($tracingMode);
    }

    # only check for new environments or commands if we're 
    # not in a verbatim-like environment or in the preamble
    if(!($inverbatim or $inpreamble))
    {

        # check if we are in a 
        #   % \begin{noindent}
        # block; this is similar to a verbatim block, the user
        # may not want some blocks of code to be touched 
        #
        # IMPORTANT: this needs to go before the trailing comments
        # are removed!
        &at_beg_noindent();

        # remove trailing comments so that any {, }, [, ]
        # that are found after % are not counted
        #
        # note that these lines are already in @lines, so we
        # can remove the trailing comments WITHOUT having
        # to put them back in
        #
        # Note that this won't match \%
        s/(?<!\\)%.*// if( $_=~ m/(?<!\\)%.*/);

        # tracing mode
        print $logfile "Line $lineCounter\t Removing trailing comments for brace count (line is already stored)\n" if($tracingMode);

        # check to see if we have \begin{something} or \[ 
        &at_beg_of_env_or_eq();

        # check to see if we have \parbox, \marginpar, or
        # something similar that might split braces {} across lines,
        # specified in %checkunmatched hash table
        &start_command_or_key_unmatched_braces();

        # check for an else statement
        &check_for_else();

        # check for a command that splits [] across lines
        &start_command_or_key_unmatched_brackets();
    }
}

# close the main file
close(MAINFILE);

# put line count information in the log file
print $logfile "Line Count of $ARGV[0]: ",scalar(@mainfile),"\n";
print $logfile "Line Count of indented $ARGV[0]: ",scalar(@lines);
if(scalar(@mainfile) != scalar(@lines))
{
  print $logfile <<ENDQUOTE
WARNING: \t line count of original file and indented file does 
\t not match- consider reverting to a back up, see $backupExtension;
ENDQUOTE
;
}
else
{
    print $logfile "\n\nLine counts of original file and indented file match";
}

# output the formatted lines to the terminal
print @lines if(!$options{s});

# if -w is active then output to $ARGV[0]
if($overwrite)
{
    open(OUTPUTFILE,">",$ARGV[0]);
    print OUTPUTFILE @lines;
    close(OUTPUTFILE);
}

# if -o is active then output to $ARGV[1]
if($outputToFile)
{
    open(OUTPUTFILE,">",$ARGV[1]);
    print OUTPUTFILE @lines;
    close(OUTPUTFILE);
}

# close the log file
close($logfile);

exit;

sub at_end_noindent{
    # PURPOSE: This matches
    #           % \end{noindent}
    #          the comment symbol IS indended!
    #
    #          This is for blocks of code that the user wants
    #          to leave untouched- similar to verbatim blocks

    if( $_ =~ m/^%\s*\\end{(.*?)}/ and $noIndentBlock{$1}) 
    {
           $inverbatim = 0;
            # tracing mode
            print $logfile "Line $lineCounter\t % \\end{no indent block} found, switching verbatim OFF \n" if($tracingMode);
    }
}

sub at_beg_noindent{
    # PURPOSE: This matches
    #           % \begin{noindent}
    #          the comment symbol IS indended!
    #
    #          This is for blocks of code that the user wants
    #          to leave untouched- similar to verbatim blocks

    if( $_ =~ m/^%\s*\\begin{(.*?)}/ and $noIndentBlock{$1}) 
    {
           $inverbatim = 1;
           # tracing mode
           print $logfile "Line $lineCounter\t % \\begin{no indent block} found, switching verbatim ON \n" if($tracingMode);
    }
}

sub start_command_or_key_unmatched_brackets{
    # PURPOSE: This matches 
    #              \pgfplotstablecreatecol[...
    #
    #              or any other command/key that has brackets [ ] 
    #              split across lines specified in the 
    #              hash tables, %checkunmatchedbracket
    #
    # How to read: ^\s*(\\)?(.*?)(\[\s*)
    #
    #       ^       line begins with
    #       \s*     any (or no)spaces
    #       (\\)?   matches a \ backslash but not necessarily
    #       (.*?)   non-greedy character match and store the result
    #       (\[\s*) match [ possibly leading with spaces

    if ($_ =~ m/^\s*(\\)?(.*?)(\s*\[)/ 
        and (scalar($checkunmatchedbracket{$2})
             or $alwaysLookforSplitBrackets)
        )
        {
            # store the command name, because $2
            # will not exist after the next match
            $commandname = $2;
            $matchedBRACKETS=0;

            # match [ but don't match \[
            $matchedBRACKETS++ while ($_ =~ /(?<!\\)\[/g);
            # match ] but don't match \]
            $matchedBRACKETS-- while ($_ =~ /(?<!\\)\]/g);

            # set the indentation
            if($matchedBRACKETS != 0 )
            {
                  # tracing mode
                  print $logfile "Line $lineCounter\t Found opening BRACKET [ $commandname\n" if($tracingMode);

                  &increase_indent($commandname);

                  # store the command name
                  # and the value of $matchedBRACKETS
                  push(@commandstorebrackets,{commandname=>$commandname,
                                      matchedBRACKETS=>$matchedBRACKETS});

            }
        }
}

sub end_command_or_key_unmatched_brackets{
    # PURPOSE:  Check for the closing BRACKET of a command that 
    #           splits its BRACKETS across lines, such as
    #
    #               \pgfplotstablecreatecol[ ...
    #
    #           It works by checking if we have any entries
    #           in the array @commandstorebrackets, and making 
    #           sure that we're not starting another command/key
    #           that has split BRACKETS (nesting).
    #
    #           It also checks that the line is not commented.
    #
    #           We count the number of [ and ADD to the counter
    #                                  ] and SUBTRACT to the counter
    if(scalar(@commandstorebrackets) 
        and  !($_ =~ m/^\s*(\\)?(.*?)(\s*\[)/ 
                    and (scalar($checkunmatchedbracket{$2})
                         or $alwaysLookforSplitBrackets))
        and $_ !~ m/^\s*%/
       )
    {
       # get the details of the most recent command name
       $commanddetails = pop(@commandstorebrackets);
       $commandname = $commanddetails->{'commandname'};
       $matchedBRACKETS = $commanddetails->{'matchedBRACKETS'};

       # match [ but don't match \[
       $matchedBRACKETS++ while ($_ =~ m/(?<!\\)\[/g);

       # match ] but don't match \]
       $matchedBRACKETS-- while ($_ =~ m/(?<!\\)\]/g);

       # if we've matched up the BRACKETS then
       # we can decrease the indent by 1 level
       if($matchedBRACKETS == 0)
       {
            # tracing mode
            print $logfile "Line $lineCounter\t Found closing BRACKET ] $commandname\n" if($tracingMode);

            # decrease the indentation (if appropriate)
            &decrease_indent($commandname);
       }
       else
       {
           # otherwise we need to enter the new value
           # of $matchedBRACKETS and the value of $command
           # back into storage
           push(@commandstorebrackets,{commandname=>$commandname,
                                       matchedBRACKETS=>$matchedBRACKETS});
           # tracing mode
           print $logfile "Line $lineCounter\t Searching for closing BRACKET ] $commandname\n" if($tracingMode);
       }
     }
}

sub start_command_or_key_unmatched_braces{
    # PURPOSE: This matches 
    #              \parbox{...
    #              \parbox[..]..{
    #              empty header/.style={
    #              \foreach \something
    #              etc
    #
    #              or any other command/key that has BRACES
    #              split across lines specified in the 
    #              hash tables, %checkunmatched, %checkunmatchedELSE
    #
    # How to read: ^\s*(\\)?(.*?)(\[|{|\s)
    #
    #       ^                  line begins with
    #       \s*                any (or no) spaces
    #       (\\)?              matches a \ backslash but not necessarily
    #       (.*?)              non-greedy character match and store the result
    #       (\[|}|=|(\s*\\))   either [ or { or = or space \

    if ($_ =~ m/^\s*(\\)?(.*?)(\[|{|=|(\s*\\))/ 
            and (scalar($checkunmatched{$2}) 
                 or scalar($checkunmatchedELSE{$2})
                 or $alwaysLookforSplitBraces)
        )
        {
            # store the command name, because $2
            # will not exist after the next match
            $commandname = $2;
            $matchedbraces=0;

            # by default, don't look for an else construct
            $lookforelse=0;
            if(scalar($checkunmatchedELSE{$2}))
            {
                $lookforelse=1;
            }

            # match { but don't match \{
            $matchedbraces++ while ($_ =~ /(?<!\\){/g);

            # match } but don't match \}
            $matchedbraces-- while ($_ =~ /(?<!\\)}/g);

            # tracing mode
            print $logfile "Line $lineCounter\t matchedbraces = $matchedbraces\n" if($tracingMode);

            # set the indentation
            if($matchedbraces > 0 )
            {
                  # tracing mode
                  print $logfile "Line $lineCounter\t Found opening BRACE { $commandname\n" if($tracingMode);

                  &increase_indent($commandname);

                  # store the command name
                  # and the value of $matchedbraces
                  push(@commandstore,{commandname=>$commandname,
                                      matchedbraces=>$matchedbraces,
                                      lookforelse=>$lookforelse,
                                      countzeros=>0});

            }
            elsif($matchedbraces<0)
            {
                # if $matchedbraces < 0 then we must be matching
                # braces from a previous split-braces command
                
                # keep matching { OR }, and don't match \{ or \}
                while ($_ =~ m/(((?<!\\){)|((?<!\\)}))/g)
                {

                     # store the match, either { or }
                     my $braceType = $1;

                     # get the details of the most recent command name
                     $commanddetails = pop(@commandstore);
                     $commandname = $commanddetails->{'commandname'};
                     $matchedbraces = $commanddetails->{'matchedbraces'};
                     $countzeros = $commanddetails->{'countzeros'};
                     $lookforelse= $commanddetails->{'lookforelse'};

                     $matchedbraces++ if($1 eq "{");
                     $matchedbraces-- if($1 eq "}");

                     # if we've matched up the braces then
                     # we can decrease the indent by 1 level
                     if($matchedbraces == 0)
                     {
                          $countzeros++ if $lookforelse;

                          # tracing mode
                          print $logfile "Line $lineCounter\t Found closing BRACE } $1\n" if($tracingMode);

                          # decrease the indentation (if appropriate)
                          &decrease_indent($commandname);

                         if($countzeros==1)
                         {
                              push(@commandstore,{commandname=>$commandname,
                                                  matchedbraces=>$matchedbraces,
                                                  lookforelse=>$lookforelse,
                                                  countzeros=>$countzeros});
                         }
                     }
                     else
                     {
                            # otherwise we need to put the command back for the 
                            # next brace count
                            push(@commandstore,{commandname=>$commandname,
                                                matchedbraces=>$matchedbraces,
                                                lookforelse=>$lookforelse,
                                                countzeros=>$countzeros});
                     }
                }
            }
        }
}

sub end_command_or_key_unmatched_braces{
    # PURPOSE:  Check for the closing BRACE of a command that 
    #           splits its BRACES across lines, such as
    #
    #               \parbox{ ...
    #
    #           or one of the tikz keys, such as
    #           
    #              empty header/.style={
    #
    #           It works by checking if we have any entries
    #           in the array @commandstore, and making 
    #           sure that we're not starting another command/key
    #           that has split BRACES (nesting).
    #
    #           It also checks that the line is not commented.
    #
    #           We count the number of { and ADD to the counter
    #                                  } and SUBTRACT to the counter
    if(scalar(@commandstore) 
      and  !($_ =~ m/^\s*(\\)?(.*?)(\[|{|=|(\s*\\))/ 
                    and (scalar($checkunmatched{$2}) 
                         or scalar($checkunmatchedELSE{$2})
                         or $alwaysLookforSplitBraces))
        and $_ !~ m/^\s*%/
       )
    {
       # keep matching { OR }, and don't match \{ or \}
       while ($_ =~ m/(((?<!\\){)|((?<!\\)}))/g)
       {
            # store the match, either { or }
            my $braceType = $1;

            # get the details of the most recent command name
            $commanddetails = pop(@commandstore);
            $commandname = $commanddetails->{'commandname'};
            $matchedbraces = $commanddetails->{'matchedbraces'};
            $countzeros = $commanddetails->{'countzeros'};
            $lookforelse= $commanddetails->{'lookforelse'};

            $matchedbraces++ if($1 eq "{");
            $matchedbraces-- if($1 eq "}");

            # if we've matched up the braces then
            # we can decrease the indent by 1 level
            if($matchedbraces == 0)
            {
                 $countzeros++ if $lookforelse;

                 # tracing mode
                 print $logfile "Line $lineCounter\t Found closing BRACE } $commandname\n" if($tracingMode);

                 # decrease the indentation (if appropriate)
                 &decrease_indent($commandname);

                if($countzeros==1)
                {
                     push(@commandstore,{commandname=>$commandname,
                                         matchedbraces=>$matchedbraces,
                                         lookforelse=>$lookforelse,
                                         countzeros=>$countzeros});
                }
            }
            else
            {
                # otherwise we need to enter the new value
                # of $matchedbraces and the value of $command
                # back into storage
                push(@commandstore,{commandname=>$commandname,
                                    matchedbraces=>$matchedbraces,
                                    lookforelse=>$lookforelse,
                                    countzeros=>$countzeros});

               # tracing mode
               print $logfile "Line $lineCounter\t Searching for closing BRACE } $commandname\n" if($tracingMode);
            }
     }
     }
}

sub check_for_else{
    # PURPOSE: Check for an else clause
    #
    #          Some commands have the form
    #
    #               \mycommand{
    #                   if this
    #               }
    #               {
    #                   else this
    #               }
    #
    #          so we need to look for the else bit, and set 
    #          the indentation appropriately.
    #
    #          We only perform this check if there's something
    #          in the array @commandstore, and if 
    #          the line itself is not a command, or comment, 
    #          and if it begins with {

    if(scalar(@commandstore) 
        and  !($_ =~ m/^\s*(\\)?(.*?)(\[|{|=)/ 
                    and (scalar($checkunmatched{$2}) 
                         or scalar($checkunmatchedELSE{$2})
                         or $alwaysLookforSplitBraces))
        and $_ =~ m/^\s*{/
        and $_ !~ m/^\s*%/
       )
    {
       # get the details of the most recent command name
       $commanddetails = pop(@commandstore);
       $commandname = $commanddetails->{'commandname'};
       $matchedbraces = $commanddetails->{'matchedbraces'};
       $countzeros = $commanddetails->{'countzeros'};
       $lookforelse= $commanddetails->{'lookforelse'};

       # increase indentation
       if($lookforelse and $countzeros==1)
       {
         &increase_indent($commandname);
       }

       # put the array back together
       push(@commandstore,{commandname=>$commandname,
                           matchedbraces=>$matchedbraces,
                           lookforelse=>$lookforelse,
                           countzeros=>$countzeros});
    }
}

sub at_beg_of_env_or_eq{
    # PURPOSE: Check if we're at the BEGINning of an environment
    #          or at the BEGINning of a displayed equation \[
    #
    #          This subroutine checks for matches of the form
    #
    #               \begin{environmentname}
    #          or
    #               \[
    #
    #          It also checks to see if the current environment
    #          should have alignment delimiters; if so, we need to turn 
    #          ON the $delimiter switch 

    # How to read
    #  m/^\s*(\$)?\\begin{(.*?)}/ 
    #
    #   ^               beginning of a line
    #   \s*             any white spaces (possibly none)
    #   (\$)?           possibly a $ symbol, but not required
    #   \\begin{(.*)?}  \begin{environmentname}
    #
    # How to read
    #  m/^\s*()(\\\[)/
    #
    #  ^        beginning of a line
    #  \s*      any white spaces (possibly none)
    #  ()       empty just so that $1 and $2 are defined
    #  (\\\[)   \[  there are lots of \ because both \ and [ need escaping 

    if( ($_ =~ m/^\s*(\$)?\\begin{(.*?)}/ or $_=~ m/^\s*()(\\\[)/) 
        and $_ !~ m/^\s*%/)
    {
       # tracing mode
       print $logfile "Line $lineCounter\t \\begin{environment} found: $2 \n" if($tracingMode);

       # increase the indentation 
       &increase_indent($2);

       # check to see if we need to look for alignment
       # delimiters
       if($lookForAlignDelims{$2})
       {
           $delimiters=1;
            # tracing mode
            print $logfile "Line $lineCounter\t Delimiter environment started: $2\n" if($tracingMode);
       }

       # check for verbatim-like environments
       if($verbatimEnvironments{$2})
       {
           $inverbatim = 1;
           # tracing mode
           print $logfile "Line $lineCounter\t \\begin{verbatim-like} found, switching ON verbatim \n" if($tracingMode);
       }
    }
}

sub at_end_of_env_or_eq{
    # PURPOSE: Check if we're at the END of an environment
    #          or at the END of a displayed equation \]
    #
    #          This subroutine checks for matches of the form
    #
    #               \end{environmentname}
    #          or
    #               \]
    #
    #          It also checks to see if the current environment
    #          had alignment delimiters; if so, we need to turn 
    #          OFF the $delimiter switch 
    
    if( ($_ =~ m/^\s*\\end{(.*?)}/ or $_=~ m/^(\\\])/)
         and $_ !~ m/\s*^%/)
    {

       # check if we're at the end of a verbatim-like environment
       if($verbatimEnvironments{$1})
       {
           $inverbatim = 0;
            # tracing mode
            print $logfile "Line $lineCounter\t \\end{verbatim-like} found, switching off verbatim \n" if($tracingMode);
       }

       # check to see if we need to turn off alignment
       # delimiters and output the current block
       if($lookForAlignDelims{$1})
       {
           $delimiters=0;

           # print the current FORMATTED block
           @block = &format_block(@block);
           foreach $line (@block)
           {
                # add the indentation and add the 
                # each line of the formatted block
                # to the output
                push(@lines,join("",@indent).$line);
           }
           # empty the @block, very important!
           @block=();

       }

       # tracing mode
       print $logfile "Line $lineCounter\t \\end{envrionment} found: $1 \n" if($tracingMode and !$verbatimEnvironments{$1});

       # decrease the indentation (if appropriate)
       &decrease_indent($1);

       # check if we want to indent lines after \end{document}
       if($1 =~ m/document/ and !$indentAfterDocument )
       {
            # tracing mode
            print $logfile "Line $lineCounter\t \\end{document} found, turning verbatim ON\n" if($tracingMode);
            $inverbatim = 1;
       }
    }
}

sub format_block{
    #   PURPOSE: Format a delimited environment such as the 
    #            tabular or align environment that contains &
    #
    #   INPUT: @block               array containing unformatted block
    #                               from, for example, align, or tabular
    #   OUTPUT: @formattedblock     array containing FORMATTED block

    # @block is the input
    my @block=@_;

    # local array variables
    my @formattedblock;
    my @tmprow=();
    my @tmpblock=();
    my @maxmstringsize=();

    # local scalar variables
    my $alignrowcounter=-1;
    my $aligncolcounter=-1;
    my $tmpstring='';
    my $row='';
    my $column='';
    my $maxmcolstrlength='';
    my $i='';
    my $j='';
    my $fmtstring='';
    my $linebreak='';

    # local hash table
    my %stringsize=();
    
    # loop through the lines in the @block
    foreach $row (@block)
    {
        # increment row counter
        $alignrowcounter++;

        # clear the $linebreak variable
        $linebreak='';

        # check for line break \\
        # and don't mess with a line that has multicolumn
        if($row =~ m/\\\\/ and $row !~ m/multicolumn/)
        {
          # remove \\ and all characters that follow
          # and put it back in later, once the measurement
          # has been done
          $row =~ s/(\\\\.*)//;
          $linebreak = $1;
        }

        # separate the row at each &, but not at \&
        @tmprow = split(/(?<!\\)&/,$row);
    
        if(scalar(@tmprow)>1 and ($row !~ m/multicolumn/))
        {
            # reset column counter
            $aligncolcounter=-1;

            # loop through each column element
            # removing leading and trailing space
            foreach $column (@tmprow)
            {
               # increment column counter
               $aligncolcounter++;
    
               # remove leading and trailing space from element
    	       $column =~ s/^\s+//;
               $column =~ s/\s+$//;
    
               # assign string size to the array
               $stringsize{$alignrowcounter.$aligncolcounter}=length($column);
               if(length($column)==0)
               {
                 $column=" ";
               }

               # put the row back together
               if ($aligncolcounter ==0)
               {
                 $tmpstring = $column;
               }
               else
               {
                 $tmpstring .= "&".$column;
               }
            }
            
            # put $linebreak back on the string, now that
            # the measurement has been done
            $tmpstring .= $linebreak;
            push(@tmpblock,$tmpstring);
        }
        else
        {
               # if there are no & then use the 
               # NOFORMATTING token
               # remove leading space
    	       s/^\s+//;
               push(@tmpblock,$row."NOFORMATTING");
        }
    }

    # calculate the maximum string size of each column
    for($j=0;$j<=$aligncolcounter;$j++)
    {
        $maxmcolstrlength=0;
        for($i=0; $i<=$alignrowcounter;$i++)
        {
            # make sure the stringsize is defined
            if(defined $stringsize{$i.$j})
            {
                if ($stringsize{$i.$j}>$maxmcolstrlength)
                {
                    $maxmcolstrlength = $stringsize{$i.$j};
                }
            }
        }
        push(@maxmstringsize,$maxmcolstrlength);
    }

    # README: printf( formatting, expression)
    #
    #   formatting has the form %-50s & %-20s & %-19s
    #   (the numbers have been made up for example)
    #       the - symbols mean that each column should be left-aligned
    #       the numbers represent how wide each column is
    #       the s represents string
    #       the & needs to be inserted
    
    # join up the maximum string lengths using "s %-"
    $fmtstring = join("s & %-",@maxmstringsize);
    
    # add an s to the end, and a newline
    $fmtstring .= "s ";
    
    # add %- to the beginning
    $fmtstring = "%-".$fmtstring;
    
    # process the @tmpblock of aligned material
    foreach $row (@tmpblock)
    {
        $linebreak='';
        # check for line break \\
        if($row =~ m/\\\\/)
        {
          # remove \\ and all characters that follow
          # and put it back in later
          $row =~ s/(\\\\.*$)//;
          $linebreak = $1;
        }

        if($row =~ m/NOFORMATTING/)
        {
            $row =~ s/NOFORMATTING//;
            $tmpstring=$row;
        }
        else
        {
          $tmpstring = sprintf($fmtstring,split(/(?<!\\)&/,$row)).$linebreak."\n";
        }
        push(@formattedblock,$tmpstring);
    }

    # return the formatted block
	@formattedblock;
}

sub increase_indent{
       # PURPOSE: Adjust the indentation
       #          of the current environment;
       #          check that it's not an environment
       #          that doesn't want indentation.

       my $command = pop(@_);

       if(scalar($indentRules{$command}))
       {
          # if there's a rule for indentation for this environment
          push(@indent, $indentRules{$command});
       }
       else
       {
          # default indentation
          if(!($noAdditionalIndent{$command} or $verbatimEnvironments{$command} or $inverbatim))
          {
            push(@indent, $defaultIndent);
            # tracing mode
            print $logfile "Line $lineCounter\t increasing indent \n" if($tracingMode);
          }
       }
}

sub decrease_indent{
       # PURPOSE: Adjust the indentation
       #          of the current environment;
       #          check that it's not an environment
       #          that doesn't want indentation.

       my $command = pop(@_);

       if(!($noAdditionalIndent{$command} or $verbatimEnvironments{$command} or $inverbatim))
       {
            pop(@indent);
            # tracing mode
            print $logfile "Line $lineCounter\t decreasing indent \n" if($tracingMode);
       }
}