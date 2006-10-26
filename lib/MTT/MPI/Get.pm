#!/usr/bin/env perl
#
# Copyright (c) 2005-2006 The Trustees of Indiana University.
#                         All rights reserved.
# Copyright (c) 2006      Cisco Systems, Inc.  All rights reserved.
# $COPYRIGHT$
# 
# Additional copyrights may follow
# 
# $HEADER$
#

########################################################################
# MPI get phase
########################################################################

# The output of this phase is the @MTT::MPI::sources array of
# structs, each with the following members:

# section_name (IN) => name of this MPI's [section] in the INI file
# version (OUT) => string version of the MPI
# tarball (OUT) => absolute pathname of the tarball
# svn (OUT) => url of SVN repository to checkout
# directory (OUT) => root of directory tree to copy
# prepare_for_build (OUT) => the name of the routine to invoke to take
#     the sources and prepare them for building in another directory

# One of tarball, svn, or directory must be supplied.

########################################################################

package MTT::MPI::Get;

use strict;
use Cwd;
use POSIX qw(strftime);
use File::Basename;
use Time::Local;
use MTT::DoCommand;
use MTT::FindProgram;
use MTT::Messages;
use MTT::Files;
use MTT::INI;
use MTT::MPI;
use MTT::Values;
use Data::Dumper;

#--------------------------------------------------------------------------

sub Get {
    my ($ini, $source_dir, $force) = @_;

    Verbose("*** MPI get phase starting\n");

    # Go through all the sections in the ini file looking for section
    # names that begin with "MPI Get:"
    MTT::DoCommand::Chdir($source_dir);
    foreach my $section ($ini->Sections()) {
        if ($section =~ /^\s*mpi get:/) {
            Verbose(">> MPI get: [$section]\n");
            _do_get($section, $ini, $source_dir, $force);
        }
    }

    Verbose("*** MPI get phase complete\n");
}

#--------------------------------------------------------------------------

# Get a new get
sub _do_get {
    my ($section, $ini, $source_dir, $force) = @_;

    Verbose("   Checking for new MPI sources...\n");

    # Simple section name
    my $simple_section = $section;
    $simple_section =~ s/^\s*mpi get:\s*//;

    my $module = Value($ini, $section, "module");
    if (!$module) {
        Warning("No module defined for MPI get [$section]; skipping\n");
        return;
    }
    my $mpi_details = Value($ini, $section, "mpi_details");
    if (!$mpi_details) {
        Warning("No mpi_details defined for MPI get [$section]; skipping\n");
        return;
    }

    # Make a directory just for this section
    MTT::DoCommand::Chdir($source_dir);
    my $section_dir = MTT::Files::make_safe_filename($section);
    $section_dir = MTT::Files::mkdir($section_dir);
    MTT::DoCommand::Chdir($section_dir);

    # Run the module
    my $ret = MTT::Module::Run("MTT::MPI::Get::$module",
                               "Get", $ini, $section, $force);
    
    # Did we get a source tree back?
    if ($ret->{success}) {
        if ($ret->{have_new}) {

            Verbose("   Got new MPI sources: version $ret->{version}\n");

            # Save other values from the section
            $ret->{full_section_name} = $section;
            $ret->{simple_section_name} = $simple_section;
            $ret->{mpi_details} = $mpi_details;
            $ret->{module_name} = "MTT::MPI::Get::$module";
            $ret->{timestamp} = timegm(gmtime());
            
            # Add this into the $MPI::sources hash
            $MTT::MPI::sources->{$simple_section}->{$ret->{version}} = $ret;

            # Save the data file recording all the sources
            MTT::MPI::SaveSources($source_dir);
        } else {
            Verbose("   No new MPI sources\n");
        }
    } else {
        Verbose("   Failed to get new test sources: $ret->{result_message}\n");
    }
}

1;
