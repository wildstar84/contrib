# Converted from menu.tcl --
#
# This file defines the default bindings for Tk menus and menubuttons.
# It also implements keyboard traversal of menus and implements a few
# other utility procedures related to menus.
#
# @(#) menu.tcl 1.34 94/12/19 17:09:09
#
# Copyright (c) 1992-1994 The Regents of the University of California.
# Copyright (c) 1994 Sun Microsystems, Inc.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

#
#	WARNING:  MODIFIED 7/7/97 AND LATER BY JIM TURNER (JWT) TO AUTO-BIND ACCELERATOR
#	SEQUENCES TO TOPLEVEL WINDOWS IN M$-WINDOWS! (ACTUALLY MAKE ACCELERATOR KEYS WORK!)
#   ALSO MODIFIED 20230625 TO PREVENT OCCASIONALLY "STUCK MENUBUTTON" (SEE Post())!
#

package Tk::Menubutton;
require Tk;

use vars qw($VERSION);
$VERSION = '4.005'; # $Id: //depot/Tkutf8/Menubutton/Menubutton.pm#4 $

use base  qw(Tk::Widget);

Construct Tk::Widget 'Menubutton';

import Tk qw(&Ev $XS_VERSION);

bootstrap Tk::Menubutton;

sub Tk_cmd { \&Tk::menubutton }

sub InitObject
{
 my ($mb,$args) = @_;
 my $menuitems = delete $args->{-menuitems};
 my $tearoff   = delete $args->{-tearoff};
#NO LONGER NEEDED:  $tearoff = 0  if ($Tk::platform eq 'MSWin32');  #JWT: ADDED 20010201 TO PREVENT WINDOZE FROM LOCKING UP WHEN abUSER CLICKS ON PERFORATION!
 $mb->SUPER::InitObject($args);
 if ($Tk::platform eq 'MSWin32')  #BUMMER!:
 {
	my ($mytext) = $args->{'-text'};

	if (defined($mytext))  #ONLY BOTHER IF -TEXT OPTION DEFINED!
	{
		my $ul;
		if (defined($args->{'-underline'}))  #USE -UNDERLINE VALUE.
		{
			$ul = $args->{'-underline'};
			$ul = undef  if ($ul < 0 || $ul > length($mytext));
		}
		else   #NO -UNDERLINE, SEE IF THERE'S A "~" IN -TEXT!
		{
			$ul = ($mytext =~ s/^(.*)~(.+)$/$1$2/) ? length($1): undef;
			if (defined($ul))   #THERE IS A "~" SET UNDERLINE TO NEXT CHAR.
			{
				$args->{'-underline'} = $ul;
				$args->{'-text'} = $mytext;   #STRIP "~" FROM -TEXT.
			}
		}
		if (defined($ul))  #BIND ALT-CHAR TO INVOKE BUTTON IF UNDERLINE OR "~".
		{
			$ul = substr($mytext,$ul,1);   #CONVERT CHAR. POSN TO ACTUAL CHAR.

			#JWT: GOT FOLLOWING BINDING SUB FROM COLLIN STARKWEATHER
			#(collin.starkweather@colorado.exe)
			#Thanks, Collin!

			$mb->toplevel->bind("<Alt-\l$ul>", sub {
				my ($x,$y) = ($mb->rootx,$mb->rooty+$mb->height);
				my $menu = $mb->menu;
				$mb->toplevel->update;
				$mb->toplevel->idletasks;
				$menu->post($x,$y);
              });
		}
	}
 }
 if ((defined($menuitems) || defined($tearoff)) && %$args)
  {
   $mb->configure(%$args);
   %$args = ();
  }
 $mb->menu(-tearoff => $tearoff) if (defined $tearoff);
 $mb->AddItems(@$menuitems) if (defined $menuitems)
}


#
#-------------------------------------------------------------------------
# Elements of tkPriv that are used in this file:
#
# cursor - Saves the -cursor option for the posted menubutton.
# focus - Saves the focus during a menu selection operation.
# Focus gets restored here when the menu is unposted.
# inMenubutton - The name of the menubutton widget containing
# the mouse, or an empty string if the mouse is
# not over any menubutton.
# popup - If a menu has been popped up via tk_popup, this
# gives the name of the menu. Otherwise this
# value is empty.
# postedMb - Name of the menubutton whose menu is currently
# posted, or an empty string if nothing is posted
# A grab is set on this widget.
# relief - Used to save the original relief of the current
# menubutton.
# window - When the mouse is over a menu, this holds the
# name of the menu; it's cleared when the mouse
# leaves the menu.
#-------------------------------------------------------------------------
#-------------------------------------------------------------------------
# Overall note:
# This file is tricky because there are four different ways that menus
# can be used:
#
# 1. As a pulldown from a menubutton. This is the most common usage.
# In this style, the variable tkPriv(postedMb) identifies the posted
# menubutton.
# 2. As a torn-off menu copied from some other menu. In this style
# tkPriv(postedMb) is empty, and the top-level menu is no
# override-redirect.
# 3. As an option menu, triggered from an option menubutton. In thi
# style tkPriv(postedMb) identifies the posted menubutton.
# 4. As a popup menu. In this style tkPriv(postedMb) is empty and
# the top-level menu is override-redirect.
#
# The various binding procedures use the state described above to
# distinguish the various cases and take different actions in each
# case.
#-------------------------------------------------------------------------
# Menu::Bind --
# This procedure is invoked the first time the mouse enters a menubutton
# widget or a menubutton widget receives the input focus. It creates
# all of the class bindings for both menubuttons and menus.
#
# Arguments:
# w - The widget that was just entered or just received
# the input focus.
# event - Indicates which event caused the procedure to be invoked
# (Enter or FocusIn). It is used so that we can carry out
# the functions of that event in addition to setting up
# bindings.
sub ClassInit
{
 my ($class,$mw) = @_;
 $mw->bind($class,'<FocusIn>','NoOp');
 $mw->bind($class,'<Enter>','Enter');
 $mw->bind($class,'<Leave>','Leave');
 $mw->bind($class,'<1>','ButtonDown');
 $mw->bind($class,'<Motion>',['Motion','up',Ev('X'),Ev('Y')]);
 $mw->bind($class,'<B1-Motion>',['Motion','down',Ev('X'),Ev('Y')]);
 $mw->bind($class,'<ButtonRelease-1>','ButtonUp');
 $mw->bind($class,'<space>','PostFirst');
 $mw->bind($class,'<Return>','PostFirst');
 return $class;
}

sub ButtonDown
{my $w = shift;
 my $Ev = $w->XEvent;
 $Tk::inMenubutton->Post($Ev->X,$Ev->Y) if (defined $Tk::inMenubutton);
}

sub PostFirst
{
 my $w = shift;
 my $menu = $w->cget('-menu');
 $w->Post();
 $menu->FirstEntry() if (defined $menu);
}


# Enter --
# This procedure is invoked when the mouse enters a menubutton
# widget. It activates the widget unless it is disabled. Note:
# this procedure is only invoked when mouse button 1 is *not* down.
# The procedure B1Enter is invoked if the button is down.
#
# Arguments:
# w - The name of the widget.
sub Enter
{
 my $w = shift;
 $Tk::inMenubutton->Leave if (defined $Tk::inMenubutton);
 $Tk::inMenubutton = $w;
 if ($w->cget('-state') ne 'disabled')
  {
   $w->configure('-state','active')
  }
}

sub Leave
{
 my $w = shift;
 $Tk::inMenubutton = undef;
 return unless Tk::Exists($w);
 if ($w->cget('-state') eq 'active')
  {
   $w->configure('-state','normal')
  }
}
# Post --
# Given a menubutton, this procedure does all the work of posting
# its associated menu and unposting any other menu that is currently
# posted.
#
# Arguments:
# w - The name of the menubutton widget whose menu
# is to be posted.
# x, y - Root coordinates of cursor, used for positioning
# option menus. If not specified, then the center
# of the menubutton is used for an option menu.
sub Post
{
 my $w = shift;
 my $x = shift;
 my $y = shift;
 return if ($w->cget('-state') eq 'disabled');
#JWT:REMOVED 20230625 TO PREVENT STUCK MENUBUTTON: return if (defined $Tk::postedMb && $w == $Tk::postedMb);
 my $menu = $w->cget('-menu');
 return unless (defined($menu) && $menu->index('last') ne 'none');

 my $tearoff = $Tk::platform eq 'unix' || $menu->cget('-type') eq 'tearoff';

 my $wpath = $w->PathName;
 my $mpath = $menu->PathName;
 unless (index($mpath,"$wpath.") == 0)
  {
   die "Cannot post $mpath : not a descendant of $wpath";
  }

 my $cur = $Tk::postedMb;
 if (defined $cur)
  {
#JWT:CHGD. TO NEXT IF/ELSE BLOCK 20230630 TO FIX ALT-KEYBINDINGS BROKEN 20230625:   Tk::Menu->Unpost(undef); # fixme
   if (defined($x) && defined($y))
    {
    	#ACTUATED BY MOUSE:
     Tk::Menu->Unpost(undef); # fixme
     return  if ($cur eq $w);  # JWT:ADDED 20230625 TO PREVENT STUCK MENUBUTTON BY UNPOSTING IF ALREADY POSTED!
    }
   elsif ($cur)
    {
    	#ACTUATED BY KEYBOARD:
    	return  if ($cur eq $w);  # JWT:ADDED 20230625 TO PREVENT STUCK MENUBUTTON BY UNPOSTING IF ALREADY POSTED!

     Tk::Menu->Unpost(undef);
    }
  }
 $Tk::cursor = $w->cget('-cursor');
 $Tk::relief = $w->cget('-relief');
 $w->configure('-cursor','arrow');
 $w->configure('-relief','raised');
 $Tk::postedMb = $w;
 $Tk::focus = $w->focusCurrent;
 # JWT:FIXME:ADDED NEXT 20230630: FOR UNKNOWN REASON, Tk::NoteBook WON'T ACCEPT FOCUS BACK, LEAVING NOTHING FOCUSED?!:
 $Tk::focus = $w->focusCurrent->parent  if ($Tk::focus =~ /NoteBook/o);
 $menu->focus;  # JWT:ADDED 20230630 TO KEEP SOME WIDGETS (LIKE Tk::JBrowseEntry) FROM STEALING FOCUS WHILST MENU POSTED!
 #Tk::JBrowseEntry WANTS FOCUS BACK REALLY BAD, BUT Tk::NoteBook DOESN'T SEEM TO WANT IT BACK AT ALL?!
 $menu->activate('none');
 $menu->GenerateMenuSelect;
 # If this looks like an option menubutton then post the menu so
 # that the current entry is on top of the mouse. Otherwise post
 # the menu just below the menubutton, as for a pull-down.

 eval
  {local $SIG{'__DIE__'};
   my $dir = $w->cget('-direction');
   if ($dir eq 'above')
    {
     $menu->post($w->rootx, $w->rooty - $menu->ReqHeight);
    }
   elsif ($dir eq 'below')
    {
     $menu->post($w->rootx, $w->rooty + $w->Height);
    }
   elsif ($dir eq 'left')
    {
     my $x = $w->rootx - $menu->ReqWidth;
     my $y = int((2*$w->rooty + $w->Height) / 2);
     if ($w->cget('-indicatoron') == 1 && defined($w->cget('-textvariable')))
      {
       $menu->PostOverPoint($x,$y,$menu->FindName($w->cget('-text')))
      }
     else
      {
       $menu->post($x,$y);
      }
    }
   elsif ($dir eq 'right')
    {
     my $x = $w->rootx + $w->Width;
     my $y = int((2*$w->rooty + $w->Height) / 2);
     if ($w->cget('-indicatoron') == 1 && defined($w->cget('-textvariable')))
      {
       $menu->PostOverPoint($x,$y,$menu->FindName($w->cget('-text')))
      }
     else
      {
       $menu->post($x,$y);
      }
    }
   else
    {
     if ($w->cget('-indicatoron') == 1 && defined($w->cget('-textvariable')))
      {
       if (!defined($y))
        {
         $x = $w->rootx+$w->width/2;
         $y = $w->rooty+$w->height/2
        }
       $menu->PostOverPoint($x,$y,$menu->FindName($w->cget('-text')))
      }
     else
      {
       $menu->post($w->rootx,$w->rooty+$w->height);
      }
    }
	$Tk::postedMb = undef  if ($Tk::platform eq 'MSWin32' && $w =~ /Optionmenu/o);   #JWT: ADDED 20010201 TO ALLOW KEYBOARD TO POP UP OPTION MENU SUBSEQUENT TIMES!
  };
 if ($@)
  {
   Tk::Menu->Unpost;
   die $@
  }

 $Tk::tearoff = $tearoff;
 if ($tearoff)
  {
   $menu->focus;
   if ($w->viewable)
    {
     $w->SaveGrabInfo;
     $w->grabGlobal;
    }
  }
}
# Motion --
# This procedure handles mouse motion events inside menubuttons, and
# also outside menubuttons when a menubutton has a grab (e.g. when a
# menu selection operation is in progress).
#
# Arguments:
# w - The name of the menubutton widget.
# upDown - "down" means button 1 is pressed, "up" means
# it isn't.
# rootx, rooty - Coordinates of mouse, in (virtual?) root window.
sub Motion
{
 my $w = shift;
 my $upDown = shift;
 my $rootx = shift;
 my $rooty = shift;
 return if (defined($Tk::inMenubutton) && $Tk::inMenubutton == $w);
 my $new = $w->Containing($rootx,$rooty);
 if (defined($Tk::inMenubutton))
  {
   if (!defined($new) || ($new != $Tk::inMenubutton && $w->toplevel != $new->toplevel))
    {
     $Tk::inMenubutton->Leave();
    }
  }
 if (defined($new) && $new->IsMenubutton && $new->cget('-indicatoron') == 0 &&
     $w->cget('-indicatoron') == 0)
  {
   if ($upDown eq 'down')
    {
     $new->Post($rootx,$rooty);
    }
   else
    {
     $new->Enter();
    }
  }
}
# ButtonUp --
# This procedure is invoked to handle button 1 releases for menubuttons.
# If the release happens inside the menubutton then leave its menu
# posted with element 0 activated. Otherwise, unpost the menu.
#
# Arguments:
# w - The name of the menubutton widget.

sub ButtonUp {
    my $w = shift;

    my $tearoff = $Tk::platform eq 'unix' || (defined($w->cget('-menu')) &&
					      $w->cget('-menu')->cget('-type') eq 'tearoff');
    if ($tearoff && (defined($Tk::postedMb)     && $Tk::postedMb == $w)
	         && (defined($Tk::inMenubutton) && $Tk::inMenubutton == $w)) {
	$Tk::postedMb->cget(-menu)->FirstEntry();
    } else {
      Tk::Menu->Unpost(undef);
    }
} # end ButtonUp

# Some convenience methods

sub menu
{
 my ($w,%args) = @_;
 my $menu = $w->cget('-menu');
 if (!defined $menu)
  {
   require Tk::Menu;
   $w->ColorOptions(\%args) if ($Tk::platform eq 'unix');
   $menu = $w->Menu(%args);
   $w->configure('-menu'=>$menu);
  }
 else
  {
   $menu->configure(%args);
  }
 return $menu;
}

sub separator   { require Tk::Menu::Item; shift->menu->Separator(@_);   }
sub command     { 
	require Tk::Menu::Item;
	if ($Tk::platform eq 'MSWin32')  #BUMMER!:
	{
		my ($w) = shift;

		#ADDED 7/7/97 BY JIM TURNER (JWT) TO BIND ACCELERATOR STRINGS!
		my ($mytext, $mycmd);
		for ($i=0;$i<$#_;$i++)   #FIND ACCELERATOR STRING AND CALLBACK.
		{
			if ($_[$i] eq '-accelerator')
			{
				$mytext = $_[$i+1];
				$mytext =~ s/Ctrl/Control/;
				$mytext = '<' . $mytext . '>';
			}
			elsif ($_[$i] eq '-command')
			{
				($mycmd) = $_[$i+1];
			}
		}
		$w->menu->Command(@_);
		if ($mytext && $mycmd)
		{
			$res = eval {return ($#{$mycmd})};  #SEE IF CALLBACK IS AN ARRAY
			$x = $w->menu->index('end');  #SAVE THIS ENTRY'S INDEX FOR BINDSUB.
			if ($res || $res eq '0')
			{
				$w->toplevel->bind($mytext, [\&accbindsub,$w,$x,@$mycmd]);
			}
			else
			{
				$w->toplevel->bind($mytext, [\&accbindsub,$w,$x,$mycmd]);
			}
		}
	}
	else
	{
		shift->menu->Command(@_);
	}
}
sub cascade     { require Tk::Menu::Item; shift->menu->Cascade(@_);     }
sub checkbutton { require Tk::Menu::Item; shift->menu->Checkbutton(@_); }
sub radiobutton { require Tk::Menu::Item; shift->menu->Radiobutton(@_); }

sub AddItems
{
 shift->menu->AddItems(@_);
}

sub entryconfigure
{
 shift->menu->entryconfigure(@_);
}

sub entrycget
{
 shift->menu->entrycget(@_);
}

sub FindMenu
{
 my $child = shift;
 my $char = shift;
 my $ul = $child->cget('-underline');
 if (defined $ul && $ul >= 0 && $child->cget('-state') ne 'disabled')
  {
   my $char2 = $child->cget('-text');
   $char2 = substr("\L$char2",$ul,1) if (defined $char2);
   if (!defined($char) || $char eq '' || (defined($char2) && "\l$char" eq $char2))
    {
     $child->PostFirst;
     return $child;
    }
  }
 return undef;
}

sub accbindsub    #ADDED 7/7/97 BY JIM TURNER (JWT) TO BIND ACCELERATOR STRINGS!
{
	my ($w) = shift;      #THIS LINE REQUIRED!
	my ($s) = shift;      #MENU
	my ($indx) = shift;   #INDEX OF MENU ENTRY CONTAINING ACCELERATOR
	my ($scmd,@ss) = @_;  #CALLBACK AND ARGS.

	my ($st) = $s->entrycget($indx,'-state');  #CHECK STATE AND
	&$scmd (@ss)  if ($st eq 'normal');        #ONLY DO IF NOT DISABLED!
}

1;

__END__


