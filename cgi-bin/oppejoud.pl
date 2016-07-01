#!/usr/bin/perl
use strict;
use warnings;
use warnings qw(FATAL utf8);
use v5.10;
use utf8;
use CGI qw(:standard start_ul);
use CGI::Carp qw(fatalsToBrowser);
use File::Basename;
use File::Copy 'mv';
use File::Temp qw(tempfile tempdir);
use DateTime;
use Encode qw(decode encode);
use JSON::XS;
use open ':std', ':encoding(UTF-8)';

$ENV{LC_ALL}='en_US.UTF-8';
$ENV{LANGUAGE}='et';

use POSIX qw (setlocale);
use Locale::Messages qw (LC_MESSAGES bind_textdomain_filter);
$ENV{OUTPUT_CHARSET} = 'UTF-8';
bind_textdomain_filter 'ee.oppejoud' => \&Encode::decode_utf8;

use Locale::TextDomain ('ee.oppejoud', '../config/LocaleData');

setlocale (LC_MESSAGES, "");

$CGI::POST_MAX = 1024 * 10;

my $q = new CGI;

my $name = getParam('name'); # professor's full name
my $firstName = getParam('firstName');
my $lastName = getParam('lastName');
my $uni = getParam('uni');
my $userUni = getParam('userUni');
my $generalImpression = getParam('generalImpression');
my $comment = getParam('comment');
my $course = getParam('course');
my $commenterIP = $q->remote_host();
my @teacherData = ();
my $cookieDropDownUni = '';
my $cookieTextInputUni = '';
my $cookieLang = '';
my $nameRegex = '^[\p{L} -]+$';
my $defaultUni = ''; #TODO
my $coder = JSON::XS->new->pretty;

my $mainFolder = '../data';
my $tmpFolder = "$mainFolder/tmp";
my $lock = "$mainFolder/lockFolder";
my $logFolder = "$mainFolder/log";
my $logFile = "$logFolder/log.txt";
my $newProfsLogFile = "$logFolder/newProfsLog.txt";
my $allProfsFilesFolder = "$mainFolder";
my $allProfsListFolder = "$mainFolder/files";
my $allProfsFile = "$allProfsListFolder/allProfessors.txt";

# moved here to prevent warning "too early to check prototype"

sub setLangCookies() {
    my $userLang = '';
    if (getParam('lang') eq 'ru') {
        $userLang = 'ru';
    } elsif (getParam('lang') eq 'et') {
        $userLang = 'et';
    } elsif (getParam('lang') eq 'en') {
        $userLang = 'en';
    }

    if ($userLang ne '') {
        $cookieLang = $q->cookie(-name  => 'lang', -value => $userLang, -expires => '+10y');
    }
}

mkdir($mainFolder) unless -d $mainFolder;

setLangCookies();

if (getParam('lang') or $q->cookie('lang')) {
    my $lang = getParam('lang') || $q->cookie('lang');
    $ENV{LANGUAGE} = $lang if $lang =~ /^(en|ru|et)$/;
}

if (getParam('action') eq 'write') {
    if ($ENV{'REQUEST_METHOD'} ne 'POST') {
        print redirect(-url => "?action=read&name=$name");
        exit;
    }
    my $dateTime = DateTime->from_epoch(epoch => time, time_zone => 'Europe/Tallinn');
    my $date = $dateTime->date;
    my $time = $dateTime->time;

    $uni ||= $userUni;
    if ($name eq '' or $name eq undef) {
        commentError(__ 'Professor\'s name can\'t be blank.');
    } elsif ($uni eq '' or $uni eq undef) {
        commentError(__ 'Please choose or enter a university.');
    } elsif ($course eq '' or $course eq undef) {
        commentError(__ 'Please enter a course name.');
    } elsif ($comment eq '' or $comment eq undef) {
        commentError(__ 'Please enter a comment.');
    } elsif ($name !~ /$nameRegex/) {
        commentError(__ 'Only letters, hyphens and spaces are allowed.');
    } elsif (length($comment) > 1000) {
        commentError(__x 'Comment can\'t be longer than {count} symbols.', count => 1000);
    } elsif (length($course) > 100) {
        commentError(__x 'Course name can\'t be longer than {count} symbols.', count => 100);
    } elsif ($generalImpression ne 'bad' and $generalImpression ne 'neutral' and $generalImpression ne 'good') {
        commentError(__ 'Unacceptable radiobutton value.');
    } else {
        $cookieDropDownUni = $q->cookie(
            -name  => 'preferredDropDownUni',
            -value => $uni,
            -expires => '+10y'
            );
        $cookieTextInputUni = $q->cookie(
            -name  => 'preferredTextInputUni',
            -value => $userUni,
            -expires => '+10y'
            );
        my $teacherFile = "$mainFolder/$name.txt";

        lockOperation();

        my ($ok, $storedIn) = readFile($teacherFile);
        if (not $ok) {
            commentError('Cannot read database. Please write to marjana.voronina@gmail.com'); # TODO
        }
        if ($storedIn) {
            $storedIn = $coder->decode($storedIn);
            @teacherData =  @{$storedIn};
        }

        my %newTeacherData = (
            university        => $uni,
            course            => $course,
            comment           => $comment,
            generalImpression => $generalImpression,
            date              => $date,
            time              => $time,
            commenterIP       => $commenterIP,
            );

        push @teacherData, \%newTeacherData;

        my $storedOut = $coder->encode(\@teacherData);

        writeStringToFile($teacherFile, $storedOut);

        if (length($comment) > 50) {
            $comment = substr($comment, 0, 50) . '…';
        }
        utf8::decode($comment);

        mkdir($logFolder) unless -d $logFolder;
        appendStringToFile($logFile, join("\x1e", $date, $time, $name, $comment) . "\n");

        unlockOperation();

        printAllHeaders();
        printTeacherData($teacherFile);
        printCommentForm(1);
        printEndHtml();
    }

} elsif (getParam('action') eq '') {
    printAllHeaders();
    printSearchPanel();
    print $q->a({-id => 'databaseLink', -href => '?action=showAllProfessors'}, __ 'Or see the database');
    print $q->p(__ 'Want to know what others say about your professor?');
    print $q->p(__ 'Want to share your experience with other students?');
    print $q->p(__ 'You are in the right place!');
    printEndHtml();
} elsif (getParam('action') eq 'project') {
    printAllHeaders();
    print $q->h1({-class => 'specialHeading'}, __ 'About the project');
    print $q->start_div({-id => 'about'});
    print $q->p(__ 'We are all different, and our goals are different as well. Some decide to go the easy way, while others prefer challenges.
Unfortunately, studying programmes are not perfect and do not account for students\' special needs.');
    print $q->p(__ 'There were times when I wished professors demanded more from me (when the course was interesting and useful), other
times I wished the requirements were lower. Harsh reality is that courses that are not compulsory for my profession took most of the time,
leaving absolutely required courses in the background.');
    print $q->p(__ encode 'UTF-8', 'Today students in most universities are allowed not only to create their own schedules, but also to choose professors.
This led me to a thought that it should be possible to “meet” your professor before you actually start attending the lectures.');
    print $q->p(__ 'Right now there are not enough feedbacks about Estonian professors on the Internet. I am hoping this project will
improve the situation.');
    print $q->p(__ 'The main goal of this project is not to rate professors according to some scale. There are no perfect or bad professors,
 you just have to find one that suits you.');
    print $q->end_div();
    printEndHtml();

} elsif (getParam('action') eq 'changes') {
    printAllHeaders();
    print $q->h1({-class => 'specialHeading'}, __ 'Recent comments:');
    mkdir($logFolder) unless -d $logFolder;
    writeStringToFile($logFile, '') unless -e $logFile;
    my $file = openFileForReading($logFile);
    my @lines = reverse <$file>;
    close($file);
    if (scalar @lines > 0) {
	print $q->start_table({-id => 'lastComments'});
	print $q->Tr( $q->th(__ 'Time added'),
		      $q->th(__ 'Professor'),
		      $q->th(__ 'Comment') );
	for (@lines) {
	    my ($date, $time, $name, $comment) = split "\x1e", $_;
	    print
		$q->Tr( $q->td({-class => 'dateTime'},$date, ' ', $time),
			$q->td($q->a({-href => "?action=read&name=$name"}, $name)),
			$q->td({-class => 'shortComment'}, $comment)
		);
	}
	print $q->end_table();
    } else { print $q->p(__ 'No comments have been added yet.'); }
    printEndHtml();
} elsif (getParam('action') eq 'contact') {
    printAllHeaders();
    print $q->h1({-class => 'specialHeading'}, __ 'Contact');
    print $q->p(__ 'Your comments and suggestions are welcome.');
    print $q->p('marjana.voronina@gmail.com');
    print $q->p({class => 'contactMe'},'✎');
    printEndHtml();
}
elsif (getParam('action') eq 'search') {
    printAllHeaders();
    printSearchPanel();
    if ($name eq '' || length($name) < 3) {
        print $q->span({-id => 'error'}, __x('Please enter at least {count} symbols.', count => 3));
    } elsif (length($name) > 30) {
        print $q->span({-id => 'error'}, __x('Query can\'t be longer than {count} symbols.', count => 30));
    } elsif ($name !~/$nameRegex/) {
        print $q->span({-id => 'error'}, __ 'Only letters, hyphens and spaces are allowed.');
    } else {
        print $q->h1(__x('Search results ({name}):', name => $name));
        opendir my $dir, $mainFolder or die "Cannot open directory: $!";
        my @foundTeachers = grep { /\.txt$/ and /$name/i } map { utf8::decode($_); $_ } readdir $dir;
        closedir $dir;

        if (@foundTeachers) {
            print $q->start_div({-id => 'searchResults'});
            for ( @foundTeachers ) {
                my $teacherName = basename($_, '.txt');
                print $q->a({-href => "?action=read&name=$teacherName"}, $teacherName);
                print $q->br();
            }
            print $q->end_div();
        } else {
            print $q->p({-id=>'error'}, __ 'Sorry, nothing was found.');
        }
	printAddButton();
    }
    printEndHtml();
} elsif (getParam('action') eq 'read') {
    printAllHeaders();
    my $teacherFile = "$mainFolder/$name.txt";
    if (-e $teacherFile) {
        printTeacherData($teacherFile);
        printCommentForm(1);
    } else {
        print $q->h1(__ 'Error');
        print $q->p(__x "Nothing was found for your query ({name}).", name => $name);
	printAddButton();
    }
    printEndHtml();
}
elsif (getParam('action') eq 'add') {
    my $submit = getParam('submit');
    my $fullName = $firstName . ' ' . $lastName;
    my $filename = "$mainFolder/$fullName.txt"; #TODO rename filename
    if ($submit eq '') {
        printAllHeaders();
        printAddForm();
    } else {
        if ($ENV{'REQUEST_METHOD'} ne 'POST') {
            print redirect(-url => '?action=add');
            exit;
        }
        if ($firstName eq '' or $lastName eq '') {
            printAllHeaders();
            printAddForm();
            print $q->span({-id => 'error'}, __ 'Please fill both fields.');
        } elsif ($firstName !~ /$nameRegex/ or $lastName !~ /$nameRegex/) {
            printAllHeaders();
            printAddForm();
            print $q->span({-id => 'error'}, __ 'Only letters, hyphens and spaces are allowed.');
        } else {
            my @results = grep {/$filename/i} <$allProfsFilesFolder/*>;
            if (@results > 0) {
                printAllHeaders();
                printAddForm();
                print $q->span({-id => 'error'}, __ 'This professor already exists in the database.');
                print $q->a({-href => "?action=read&name=" . basename($results[0], '.txt')}, __ 'View page');
            } else {
                lockOperation();
                if ($fullName ne 'update all') {
		    writeStringToFile($filename, '');
		    my $userIP = $q->remote_host();
		    my $dateTime = DateTime->from_epoch(epoch => time, time_zone => 'Europe/Tallinn');
		    my $date = $dateTime->date;
		    my $time = $dateTime->time;
		    addNewProfDataToLog($date, $time, $fullName, $userIP);
		}

                if (! -d $allProfsListFolder) {
                    mkdir($allProfsListFolder);
                }

                opendir my $dir, $allProfsFilesFolder or die "Cannot open directory: $!";
                my @files = grep(/\.txt$/,readdir($dir));
                my $teachersList = '';
                foreach (@files) {
                    $teachersList .= basename($_, '.txt') ."\n";
                }
                close $dir;
                utf8::decode($teachersList);
                writeStringToFile($allProfsFile, $teachersList);
                unlockOperation();
                print redirect(-url => "?action=read&name=$fullName");
                return;
            }
        }
    }
    printEndHtml();

} elsif (getParam('action') eq 'showAllProfessors') {
    printAllHeaders();

    #TODO create a function for opening this directory!

    opendir my $dir, $allProfsFilesFolder or die "Cannot open directory: $!";
    my @files = grep(/\.txt$/,readdir($dir));
    close $dir;
    @files = sort(@files);

    my $numberOfProfs = scalar @files;
    print $q->h1({class => 'specialHeading'}, __x('All professors ({count}):', count => $numberOfProfs));
    if ($numberOfProfs < 1) { #
	print $q->p( __ 'No professors have been added yet.'); #
    } else { #
	printAddButton();
	print $q->start_div({id => 'allProfsList'});
	foreach (@files){
	    utf8::decode($_);
	    my $basename = basename($_, '.txt');
	    print $q->a({class => 'allProfsLink', href => "?action=read&name=$basename"}, $basename);
	    print $q->br();
	}
    }
    printAddButton();
    print $q->end_div();
    printEndHtml();
} else {
    print redirect(-url => '?');
}

sub printNavbar {
    my $action = getParam('action');
    if ($action eq 'read') {
        $action .= "&name=$name";
    }
    print $q->start_div({class=>'navbar'});

    my @links = (
	{'?' => 'Main page'},
	{'?action=changes' => 'Recent comments'},
	{'?action=project' => 'About the project'},
	{'?action=contact' => 'Contact'},
	);

    my @lang = (
	{"?action=$action&lang=et" => 'EST'},
	{"?action=$action&lang=ru" => 'RUS'},
	{"?action=$action&lang=en" => 'ENG'},
	);

    printNavbarUl('links', @links);
    printNavbarUl('lang', @lang);

    print $q->end_div(); # .navbar
}

sub printNavbarUl {
    my ($id, @ulName) = @_;

    print start_ul({-id => $id});
    printListItems(@ulName);
    print end_ul();
}

sub printListItems {
    my (@array) = @_;
    for my $href ( @array ) {
	for my $_ ( keys %$href ) {
	    print li(a({href => $_}, __ $href->{$_}));
	}
    }
}

sub printHeader {
    print '<header>';
    print $q->p({-class => 'centered', -id => 'slogan'}, $q->a({-href => '/'}, __ 'Find a perfectly suitable professor!'));
    print '</header>';
}

sub printSearchPanel {
    print $q->start_form(
        -method   => 'GET',
        -class    => 'centered',
        -id       => 'searchForm',
        );
    print $q->p({-class => 'enterName'}, __ 'Enter professor\'s name:');
    print $q->p('︾');
    print $q->textfield(
        -name     => 'name',
        -value    => $name,
        -class    => 'awesomplete',
        -id       => 'searchName',
        -required => 'required',
        -override => 1
        );
    print $q->hidden(
        -name     => 'action',
        -value    => 'search',
        -override => 1
        );
    print $q->br();
    print $q->submit(
        -value    => __ 'SEARCH',
        -class    => 'button greenButton'
        );
    print $q->end_form;
}

sub printListOfUniversities {

    my $allUnisFolder = "$mainFolder/files";
    mkdir($allUnisFolder) unless -d $allUnisFolder;

    my $allUnisFile = "$allUnisFolder/universities.txt";
    unless (-f $allUnisFile) {
	writeStringToFile($allUnisFile, '');
    }

    my %universities = ();

    my ($ok, $storedIn) = readFile($allUnisFile);
    if (not $ok) {
	commentError('Cannot read database. Please write to marjana.voronina@gmail.com'); # TODO
    }
    if ($storedIn) {
	$storedIn = $coder->decode($storedIn);
	%universities =  %{$storedIn};
    }

    my @values = map { $q->optgroup(-name => $_, -values => $universities{$_}) } sort keys %universities;
    unshift @values, $defaultUni;
    print $q->popup_menu(
        -name     => 'uni',
        -values   => \@values,
        -default  => getPreferredDropDownUni());
    print $q->p({-id => 'userUni'}, __ 'Couldn\'t find yours? Enter it manually.');
    print $q->textfield(
        -name     => 'userUni',
        -value    => getPreferredTextInputUni()
        );
}

sub printMeta {
    my $dtd      = '<!DOCTYPE html>';   # HTML5
    my $html = start_html(
        -head     => meta({-name => 'viewport', -content => 'width=device-width'}),
        -encoding => 'utf-8',
        -title    => $name || __ 'Find a perfectly suitable professor!',
        -style    => [{-src=>'/css/my.css'}, {-src=>'/css/awesomplete.css'}],
        );
    $html =~ s{<!DOCTYPE.*?>}{$dtd}s;
    print $html;
}

sub printAllHeaders {
    my $csp = "default-src 'none'; script-src 'self'; connect-src 'self'; img-src 'self' data:; style-src 'self';";
    print $q->header(
        -charset  => 'UTF-8',
        -cookie   => [$cookieDropDownUni, $cookieTextInputUni, $cookieLang],
        '-Content-Security-Policy'   => $csp,
        '-X-Content-Security-Policy' => $csp,
        '-X-Webkit-CSP'              => $csp,
        );
    printMeta();
    print $q->start_div({id => 'container'});
    printNavbar();
    print $q->start_div({id => 'body'});
    printHeader();
}

sub printAddForm {
    print $q->h2({-class => 'specialHeading'}, __ 'Add a new professor');
    print $q->start_form(
        -id        => 'addProfForm',
        -method    => 'POST',
        -action    => '',
        );
    print $q->p(__('Professor\'s name'));
    print $q->textfield(
        -name      => 'firstName',
        -id        => 'newTeacherFirstName',
        -maxlength => 30,
        -required  => 'required',
        );
    print $q->p(__ 'Professor\'s lastname');
    print $q->textfield(
        -name => 'lastName',
        -id        => 'newTeacherLastName',
        -maxlength => 30,
        -required  => 'required',
        );
    print $q->hidden(
        -name => 'action',
        -value => 'add',
        -override  => 1,
        );
    print $q->br();
    print $q->submit(
        -name => 'submit',
        -value => __ 'ADD',
        -class => 'button greenButton'
        );
    print $q->end_form;
}

sub getParam {
    my ($param) = @_;
    my $result = $q->param($param);
    return '' unless defined $result; # TODO undefs are ok too
    utf8::decode($result);
    $result = escapeHTML($result);
    $result =~ s/^\s+|\s+$//g; # trim
    $result =~ s/\s+/ /g; # multiple spaces

    if ($param  eq 'name') {
        $result =~ s!/!!g; # remove slashes
        $result =~ s/\.//g; # remove dots
    }
    return $result;
}

sub printTeacherData {
    my ($teacherFile) = @_;
    print $q->h1({-class => 'specialHeading'}, __x('Professor: {name}', name => $name));
    print $q->a({-href => '#newComment', -class => 'button greenButton'}, __ 'Add a comment');
    print $q->start_div({-class => 'left'}); #TODO rename
    print $q->h2(__ 'Comments:');

    if (-z $teacherFile) {
        print $q->p(__ 'Comments were not added yet.');
        print $q->hr();
        return;
    }
    my ($ok, $storedIn) = readFile($teacherFile);
    if (not $ok) { # TODO
        1;
    }

    my $test = $coder->decode($storedIn);
    @teacherData =  @{$test};

    for my $commentData (reverse(@teacherData) ) {
        my $emoticon = '';
        if ($commentData->{generalImpression} eq 'good') {
            $emoticon = '😊';
        } elsif ($commentData->{generalImpression} eq 'bad') {
            $emoticon = '😞';
        } elsif ($commentData->{generalImpression} eq 'neutral') {
            $emoticon = '😐';
        }

        print $q->div({-class=>"shadowed blackOnWhite comment"},
                      $q->start_table({-class => "uniAndCourse"}),
                      $q->Tr ($q->td(__('University:')), $q->td({class=>'university'},$commentData->{university})),
                      $q->Tr ($q->td(__('Course:')), $q->td({class => 'course'},$commentData->{course})),
                      $q->end_table(),
                      $q->p({-class   => 'centered commentText'}, "$commentData->{comment}"),
                      $q->div({-class => 'emoticon'}, "$emoticon"),
                      $q->p({-class   => 'centered date'}, "<time datetime=\"$commentData->{date} $commentData->{time}\">$commentData->{date} $commentData->{time}</time>"),
            );
        print $q->start_div({-class => 'divider'});
        print $q->hr({-class        => 'hrLeft'});
        print $q->span({-class      => 'hrText'}, '↑↑↑');
        print $q->hr({-class        => 'hrRight'});
        print $q->end_div();
    }
    print $q->end_div();
}

sub printCommentForm {
    my ($clear) = @_;
    print $q->h2({-class => 'specialHeading', -id => 'newComment'}, __ 'Add your comment:');
    print $q->start_form(
        -method    => 'POST',
        -action    => "?action=read&name=$name",
        -class     => 'addCommentForm',
        );
    print $q->hidden(
        -name      => 'action',
        -value     => 'write',
        -override  => 1,
        );
    print $q->hidden(
        -name      => 'name',
        -value     => $name,
        -override  => 1,
        );
    print $q->p(__ 'University:');
    printListOfUniversities();
    print $q->p(__ 'Course name:');
    print $q->textfield(
        -name=> 'course',
        -maxlength => 100,
        -required  => 'required',
        -value     => $clear ? '' : $course || '',
        -override  => 1,
        );
    print $q->p(__ 'Comment:');
    print $q->textarea(
        -name=> 'comment',
        -rows      => 3,
        -class     => 'commentArea',
        -maxlength => 1000,
        -required  => 'required',
        -value     => $clear ? '' : $comment || '',
        -override  => 1,
        );
    print $q->p(__ 'General impression:');
    print $q->start_div({-id => 'impressionRadioButtons'});
    print $q->radio_group(
        -name      => 'generalImpression',
        -values    => ['bad', 'neutral', 'good'],
        -default   => $clear ? 'neutral' : $generalImpression || 'neutral',
        -labels    => {'bad' => '😞('. __('bad') . ')' , 'neutral' => '😐(' . __('neutral') . ')', 'good' => '😊('. __('good') . ')'},
        -override  => 1,
        );
    print $q->end_div();
    print $q->br();
    print $q->submit(
        -value     => __ 'SEND',
        -class     => 'button greenButton'
        );
    print $q->end_form;
}

sub readFile {
    my ($file) = @_;
    utf8::encode($file); # filenames are bytes!
    if (open(my $IN, '<:encoding(UTF-8)', $file)) {
        local $/ = undef; # Read complete files
        my $data = <$IN>;
        close $IN;
        return (1, $data);
    }
    return (0, '');
}

sub writeStringToFile {
    my ($file, $string) = @_;
    utf8::encode($file);
    # Create tmp folder if does not exist
    mkdir($tmpFolder) unless -d $tmpFolder;
    my ($TEMP, $tempFile) = tempfile(DIR => $tmpFolder);
    chmod(0660, $tempFile);
    binmode($TEMP, ':encoding(UTF-8)');
    print $TEMP $string;
    close($TEMP);
    mv($tempFile, $file) or die "Move failed: $!";
}

sub appendStringToFile {
    my ($file, $string) = @_;
    utf8::encode($file);
    open(my $OUT, '>>:encoding(UTF-8)', $file)
        or die "Cannot write $file : $!", '500 INTERNAL SERVER ERROR';
    print $OUT  $string;
    close($OUT);
}

sub openFileForReading {
    my ($filename) = @_;
    utf8::encode($filename);
    open(my $file, '<:encoding(UTF-8)', $filename) or die ("Could not open the file $filename for reading");
    return $file;
}

sub getPreferredDropDownUni {
    my $value = $q->cookie('preferredDropDownUni') || $defaultUni;
    utf8::decode($value);
    return $value;
}

sub getPreferredTextInputUni {
    my $value = $q->cookie('preferredTextInputUni') || $defaultUni;
    utf8::decode($value);
    return $value;
}

sub lockOperation {
    while (!mkdir($lock, 0644)) {
        my $mtime = (stat $lock)[9]; # time created in seconds
        if (-d $lock and time() - $mtime  > 10) {
            unlockOperation();
            next;
        }
        sleep(0.3);
    }
    return;
}

sub unlockOperation {
    rmdir($lock);
    return;
}

sub commentError {
    my ($message) = @_;
    my $teacherFile = "$mainFolder/$name.txt";
    printAllHeaders();
    print $q->p({-id => 'error'}, $message);
    printCommentForm();
    printTeacherData($teacherFile);
    printEndHtml();
    exit 2; # TODO
}

sub printEndHtml {
    print $q->end_div(); # close '#body'
    print $q->end_div(); # close '#container'
    if (getParam('action') eq '' or getParam('action') eq 'search') {
        print q{<script src='/js/awesomplete.js'></script>};
    } else {
        print q{<script src='/js/scroll.js'></script>};
    }
    print q{<script src='/js/my.js'></script>};
    print $q->end_html;
}

sub addNewProfDataToLog {
    my ($date, $time, $profName, $userIP ) = @_;
    mkdir($logFolder) unless -d $logFolder;
    appendStringToFile($newProfsLogFile, join("\x1e", $date, $time, $profName, $userIP) . "\n");
}

sub printAddButton {
    print $q->a({-class => 'button greenButton', -href => '?action=add'}, __ 'Add a new professor!');
}
