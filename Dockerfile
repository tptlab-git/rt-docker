FROM harbor.ntppool.org/perlorg/base-os:3.17.3

ENV RTVERSION 5.0.7

RUN addgroup rt && adduser -D -G rt rt

RUN apk --no-cache upgrade; \
   apk add --no-cache \
     gnupg emacs-nox \
     gd-dev graphviz perl-graphviz perl-gd perl-gdgraph \
     mini-sendmail ssmtp tzdata curl \
     perl-posix-strftime-compiler \
     perl-cache-cache perl-html-tree perl-regexp-common \
     perl-xml-rss perl-starlet perl-server-starter \
     perl-parallel-prefork perl-log-dispatch \
     perl-datetime-format-natural \
     perl-module-util perl-class-mix \
     perl-date-manip perl-scope-upper \
     perl-www-mechanize perl-parallel-forkmanager \
     perl-dbix-searchbuilder perl-html-formatter \
     perl-html-mason perl-html-mason-psgihandler \
     perl-plack

# Install more dependencies (cached in the image in this step; and upgraded from apk as needed)
RUN cpanm HTML::Mason Moose Locale::Maketext::Fuzzy DBIx::SearchBuilder HTML::Formatter \
  Crypt::X509 String::ShellQuote Regexp::IPv6 Text::Password::Pronounceable \
  Regexp::Common::net::CIDR Data::ICal Symbol::Global::Name HTML::RewriteAttributes \
  Text::WikiFormat Text::Quoted HTML::Quoted UNIVERSAL::require Module::Versions::Report \
  Time::ParseDate MIME::Types Data::GUID Text::Wrapper \
  IO::Socket::SSL JSON::XS JSON LWP::Simple XML::RSS Regexp::Common \
  Plack Plack::Handler::Starman Plack::Handler::Starlet Log::Dispatch Locale::Maketext Encode \
  Digest::SHA Digest::MD5 DBI CGI CGI::PSGI Mail::Header Net::CIDR \
  JavaScript::Minifier::XS HTML::Scrubber CPAN \
  Term::ReadKey Apache::Session CSS::Squish Date::Extract DateTime::Format::Natural \
  CSS::Minifier::XS Convert::Color Business::Hours Email::Address::List CGI::Emulate::PSGI \
  Crypt::Eksblowfish Date::Manip Scope::Upper HTML::Mason::PSGIHandler \
  Data::Page::Pageset Tree::Simple MIME::Entity Role::Basic \
  Email::Sender::Simple Email::Sender::Transport::SMTP \
  MooX::late MooX::HandlesVia \
  CPAN Locale::PO \
  && rm -fr ~/.cpanm

# modules with problems installing
RUN cpanm HTML::FormatText::WithLinks::AndTables HTML::FormatText::WithLinks \
  GraphViz GD::Text && rm -fr ~/.cpanm

# test fails on Alpine, ignore them...
RUN cpanm -n PerlIO::eol && rm -fr ~/.cpanm

# Doesn't pass tests without a tty?  MooX::* above is for this. 
RUN cpanm -f GnuPG::Interface && rm -fr ~/.cpanm

# For RT::Extension::REST2
RUN cpanm Path::Dispatcher MooseX::Role::Parameterized Web::Machine Module::Path Pod::POM && rm -fr ~/.cpanm
RUN cpanm -f Test::WWW::Mechanize::PSGI && rm -fr ~/.cpanm

# autoconfigure cpan shell for RT installer
RUN cpan < /dev/null

# external html parser for RT
RUN apk add --no-cache w3m

RUN mkdir /usr/src
RUN curl -fLs https://download.bestpractical.com/pub/rt/release/rt-$RTVERSION.tar.gz | tar -C /usr/src -xz


WORKDIR /usr/src/rt-$RTVERSION

ADD smtp.patch /tmp/
RUN patch -p1 < /tmp/smtp.patch && rm /tmp/smtp.patch

RUN ./configure \
   --prefix=/opt/rt \
   --with-web-handler=standalone \
   --with-db-type=mysql \
   --with-db-rt-host=mysql \
   --with-web-user=rt \
   --with-web-group=rt \
   --enable-externalauth 

RUN make fixdeps && rm -fr ~/.cpan
RUN make testdeps
RUN make install

ENV PERL5LIB=/opt/rt/lib

RUN cpanm RT::Extension::MergeUsers && rm -fr ~/.cpanm
RUN cpanm RT::Extension::MandatoryFields

WORKDIR /opt/rt

# use mini-sendmail instead of busybox sendmail, commented out
# because the busybox sendmail seems to work.
# RUN ln -sf /var/lib/mini-sendmail/mini_sendmail /usr/sbin/sendmail

# ssmtp configuration
RUN perl -i -pe 's{^mailhub=.*}{mailhub=localhost}' /etc/ssmtp/ssmtp.conf

ADD run /opt/rt/

EXPOSE 8000

CMD /opt/rt/run
