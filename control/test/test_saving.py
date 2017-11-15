###########################################################################
# This file is part of LImA, a Library for Image Acquisition
#
#  Copyright (C) : 2009-2017
#  European Synchrotron Radiation Facility
#  BP 220, Grenoble 38043
#  FRANCE
# 
#  Contact: lima@esrf.fr
# 
#  This is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
# 
#  This software is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, see <http://www.gnu.org/licenses/>.
############################################################################

from __future__ import print_function

import sys
import time
import argparse

from Lima import Core
from Lima import Simulator

Core.DEB_GLOBAL(Core.DebModTest)

class TestSaving :

    Core.DEB_CLASS(Core.DebModTest, 'TestSaving')

    @Core.DEB_MEMBER_FUNCT
    def __init__(self):
        self.simu = Simulator.Camera()
        self.simu_hw = Simulator.Interface(self.simu)
        self.ct_control = Core.CtControl(self.simu_hw)        
        self.ct_saving =self.ct_control.saving()
        self.ct_acq =self.ct_control.acquisition()

        # exclude cbfminiheader, it does not support unsigned 32_int
        self.limaformat2suffix = {self.ct_saving.CBFFormat: '.cbf',
 #                      self.ct_saving.CBFMiniHeader: '.cbf',
                       self.ct_saving.EDF: '.edf',
                       self.ct_saving.EDFGZ: '.edf.gz',
                       self.ct_saving.EDFLZ4: '.edf.lz4',
                       self.ct_saving.FITS: '.fits',
                       self.ct_saving.HDF5: '.h5',
                       self.ct_saving.RAW: '.raw',
                       self.ct_saving.TIFFFormat: '.tiff'}
        self.format2limaformat = {'cbf':self.ct_saving.CBFFormat,
#                                  'cbfminiheader': self.ct_saving.CBFMiniHeader,
                                  'edf': self.ct_saving.EDF,
                                  'edfgz': self.ct_saving.EDFGZ,
                                  'edflz4': self.ct_saving.EDFLZ4,
                                  'fits': self.ct_saving.FITS,
                                  'hdf5': self.ct_saving.HDF5,
                                  'raw': self.ct_saving.RAW,
                                  'tiff': self.ct_saving.TIFFFormat}
        self.overwrite2limaoverwrite={'abort': self.ct_saving.Abort,
                                      'append': self.ct_saving.Append,
                                      'multiset': self.ct_saving.MultiSet,
                                      'overwrite': self.ct_saving.Overwrite} 
    @Core.DEB_MEMBER_FUNCT               
    def __del__(self):
		del self.ct_control
                del self.simu_hw
                
    @Core.DEB_MEMBER_FUNCT
    def start(self, exp_time, nb_frames, directory, prefix, form, overwrite,framesperfile,repeats):
        # TIFF does not support multiple frames per file
        if  form == 'tiff' or form == 'cbf': fpf = 1
        else: fpf= framesperfile
        print('[%d] Prepare acquistion: %2.4f sec. %d frames, %s/%s, <%s>, %d FramesPerFile (%s)'%(repeats, exp_time, nb_frames,directory,prefix,form.upper(),fpf, overwrite))
        self.ct_acq.setAcqExpoTime(exp_time)
        self.ct_acq.setAcqNbFrames(nb_frames)
        self.ct_saving.setDirectory(directory)
        self.ct_saving.setPrefix(prefix)
        lima_format=self.format2limaformat[form]
        self.ct_saving.setFramesPerFile(fpf)
        self.ct_saving.setFormat(lima_format)
        self.ct_saving.setSuffix(self.limaformat2suffix[lima_format])        
        self.ct_saving.setOverwritePolicy(self.overwrite2limaoverwrite[overwrite])
        self.ct_saving.setSavingMode(self.ct_saving.AutoFrame)
        self.ct_saving.setNextNumber(0)
        self.repeats = repeats
        self.ct_control.prepareAcq()
        deb.Trace('[%d] PrepareAcq finished'%(repeats))
        self.ct_control.startAcq()

    @Core.DEB_MEMBER_FUNCT
    def waitAcq(self):
        def acq_status():
            return self.ct_control.getStatus().AcquisitionStatus
        while acq_status() == Core.AcqRunning:
            time.sleep(0.1)
            sys.stdout.write(str(self.ct_control.getStatus()) + '\r')
            sys.stdout.flush()
        print()
        deb.Trace('[%d] Acq. finished'%self.repeats)




@Core.DEB_FUNCT
def main(argv):
	parser = argparse.ArgumentParser(description='A Lima test program for saving format')
        parser.add_argument('-v', '--verbose', help='verbose mode, up to vvv', required=False, action='count')
        parser.add_argument('-e', '--exposure', type=float, help='exposure time in sec.', required=False,default=0.1)
        parser.add_argument('-n', '--nbframes', type=int, help='number of frames.', required=False, default=1)
        if sys.platform == 'win32': format_list = ['all','cbf','edf','edfgz','hdf5','raw']
        else: format_list = ['all','cbf','edf','edfgz','edflz4','fits','hdf5','tiff','raw']
        format_list.sort()
        parser.add_argument('-f', '--format', help='saving format', choices=format_list, required=False, default='all', nargs='+')
        parser.add_argument('-d', '--directory', help='saving directory', required=False, default='./data')
        parser.add_argument('-p', '--prefix', help='file name prefix', required=False, default='lima_test_format_')
        parser.add_argument('-o', '--overwrite', help='overwrite mode', choices=['abort','append','multiset','overwrite'], required=False, default='abort')        
        parser.add_argument('-F', '--framesperfile', help='number of frames per file', type=int, required=False, default=1)        
        parser.add_argument('-R', '--repeats', help='number of frames per file', type=int, required=False, default=1)        
        args = parser.parse_args()

        if args.verbose == 1:
            Core.DebParams.setTypeFlags(Core.DebTypeTrace)
            Core.DebParams.setModuleFlags(Core.DebModTest)
        elif args.verbose == 2:
            Core.DebParams.setTypeFlags(Core.DebTypeTrace)
            Core.DebParams.setModuleFlags(Core.DebParams.AllFlags)
        elif args.verbose >= 3:
            Core.DebParams.setTypeFlags(Core.DebParams.AllFlags)
            Core.DebParams.setModuleFlags(Core.DebParams.AllFlags)
	exp_time = 0.1

	test_saving = TestSaving()

        if args.format == ['all']:
            format_list=test_saving.format2limaformat.keys()
        else:
            format_list = args.format
        format_list.sort()
        
        for f in format_list:
            for r in range(1,args.repeats+1):
                try:
                    test_saving.start(args.exposure, args.nbframes, args.directory, args.prefix, f, args.overwrite, args.framesperfile, r)
                except Core.Exception, e:
                    raise RuntimeError
                    
                test_saving.waitAcq()

            
if __name__ == '__main__':
	main(sys.argv)


