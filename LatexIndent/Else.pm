package LatexIndent::Else;
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
#	Chris Hughes, 2017
#
#	For all communication, please visit: https://github.com/cmhughes/latexindent.pl
use strict;
use warnings;
use LatexIndent::Tokens qw/%tokens/;
use LatexIndent::TrailingComments qw/$trailingCommentRegExp/;
use LatexIndent::Switches qw/$is_m_switch_active $is_t_switch_active $is_tt_switch_active/;
use LatexIndent::LogFile qw/$logger/;
use Data::Dumper;
use Exporter qw/import/;
our @ISA = "LatexIndent::Document"; # class inheritance, Programming Perl, pg 321
our @EXPORT_OK = qw/check_for_else_statement/;
our $elseCounter;

# store the regular expresssion for matching and replacing the \else statements
our $elseRegExp = qr/
                  (
                    \\else  
                    \h*     # possible horizontal space
                    (\R*)   # possible line breaks after \else statement
                  )
                  (.*?)$
            /sx;

sub check_for_else_statement{
    my $self = shift;
    $logger->trace("*Looking for \\else statement (${$self}{name})") if $is_t_switch_active;

    ${$self}{body} =~ s/$elseRegExp(\h*)($trailingCommentRegExp)?
                       /   
                      # create a new IfElseFi object
                      my $else = LatexIndent::Else->new(begin=>$1,
                                                              name=>${$self}{name},
                                                              storageNameAppend=>"else",
                                                              body=>$3,
                                                              end=>q(),
                                                              linebreaksAtEnd=>{
                                                                begin=>$2?1:0,
                                                                body=>0,
                                                                end=>0,
                                                              },
                                                              aliases=>{
                                                                # begin statements
                                                                BeginStartsOnOwnLine=>"ElseStartsOnOwnLine",
                                                                # end statements
                                                                BodyStartsOnOwnLine=>"ElseFinishesWithLineBreak",
                                                              },
                                                              modifyLineBreaksYamlName=>"ifElseFi",
                                                              endImmediatelyFollowedByComment=>0,
                                                              horizontalTrailingSpace=>q(),
                                                            );
                      # log file output
                      $logger->trace("*else found: ${$self}{name}")if $is_t_switch_active;
         
                      # the settings and storage of most objects has a lot in common
                      $self->get_settings_and_store_new_object($else);
                      ${@{${$self}{children}}[-1]}{replacementText};
                      /xse;
        return;
}

sub remove_line_breaks_begin{
    # the \else command can need a trailing white space if the line breaks have been removed after it and
    # there is no white space
    my $self = shift;
    my $BodyStringLogFile = ${$self}{aliases}{BodyStartsOnOwnLine}||"BodyStartsOnOwnLine";
    $logger->trace("Removing linebreak at the end of begin (see $BodyStringLogFile)");
    ${$self}{begin} =~ s/\R*$//sx;
    ${$self}{begin} .= " " unless(${$self}{begin} =~ m/\h$/s or ${$self}{body} =~ m/^\h/s or ${$self}{body} =~ m/^\R/s );
    ${$self}{linebreaksAtEnd}{begin} = 0;
}

sub tasks_particular_to_each_object{
    my $self = shift;

    # search for headings (important to do this before looking for commands!)
    $self->find_heading;

    # search for commands and special code blocks
    $self->find_commands_or_key_equals_values_braces_and_special;
    return;
}

sub get_indentation_information{
    return q();
}

sub create_unique_id{
    my $self = shift;

    $elseCounter++;

    ${$self}{id} = "$tokens{else}$elseCounter";
    return;
}

1;
