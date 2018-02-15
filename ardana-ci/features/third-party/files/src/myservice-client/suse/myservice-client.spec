#
# Copyright (c) 2018 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# spec file for package myservice-client
# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

Name:           myservice-client
Version:        1.0
Release:        0
License:        MIT
Summary:        myservice client package
#Url:
#Group:
#Source:         myservice-client
#Patch:
#BuildRequires:
#PreReq:
#Provides:
BuildRoot:      %{_tmppath}/%{name}-%{version}-build

%description
The myservice-client installs this rpm.

%prep
#%setup -q
#cd %{_topdir}/build
#rm -rf %{name}-%{version}.0
#cp -rf %{_topdir}/%{name}/src/%{name}-%{version}.0 .
#cd %{name}-%{version}.0
#/usr/bin/chmod -Rf a+rX,u+w,g-w,o-w .


%build
#cd %{name}-%{version}.0
make dir_setup DESTDIR=%{buildroot} %{?_smp_mflags}

%install
#cd %{name}-%{version}.0
sudo make install DESTDIR=%{buildroot} %{?_smp_mflags}

%post

%postun

%files
%defattr(-,root,root)
/usr/local/bin/myservice-client
/usr/local/share/man/man1/myservice-client.1
