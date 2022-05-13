; nascam_imager_readfile.pro (c) 2020 Darren Chaddock
;
; This program may be freely used, edited, and distributed
; as per the below MIT License. Use at your own risk.
;
; NAME:
;     NASCAM_IMAGER_READFILE
;
; VERSION:
;     1.0.0
;
; PURPOSE:
;     This program is intended to be a general tool for reading
;     NORSTAR NASCAM all-sky camera data.
;
; EXPLANATION:
;     NASCAM imager data files are one-minute tarred PNG files. This
;     readfile will extract the metadata and image data from a file,
;     returning the data into two variables specified during calling.
;
; CALLING SEQUENCE:
;     NASCAM_IMAGER_READFILE, filename, images, metadata, /KEYWORDS
;
; INPUTS:
;     filename  - a string OR array of strings containing valid NASCAM image filenames
;
; OUTPUTS:
;     images    - a WIDTH x HEIGHT x NFRAMES array of unsigned integers or bytes
;     metadata  - a NFRAMES element array of structures
;
; KEYWORDS:
;     FIRST_FRAME       - only read the first frame of the PNG tarball file
;     ASSUME_EXISTS     - assume that the filename(s) exist (slightly faster)
;     COUNT             - returns the number of image frames (usage ex. COUNT=nframes)
;     VERBOSE           - set verbosity to level 1
;     VERY_VERBOSE      - set verbosity to level 2
;     SHOW_DATARATE     - show the read datarate stats for each file processed (usually used
;                         with /VERBOSE keyword)
;     UNTAR_DIR         - specify the directory to untar the PNG tar files to, default
;                         is 'C:\nascam_imager_readfile_working' on Windows and
;                         '~/nascam_imager_readfile_working' on Linux (usage
;                         ex. UNTAR_DIR='path\for\files')
;     NO_UNTAR_CLEANUP  - don't remove files after untarring to the UNTAR_DIR and reading
;
; CATEGORY:
;     Image, File reading
;
; USAGE EXAMPLES:
;     1) Read single file
;         IDL> filename = '20100101_0600_fsmi_nascam-pmax01.png.tar'
;         IDL> nascam_imager_readfile,filename,img,meta
;
;     2) Read list of files
;         IDL> f = file_search('\path\to\nascam\data\stream0.png\2010\01\01\fsmi_nascam-pmax01\ut06\*')
;         IDL> nascam_imager_readfile,f,img,meta
;
;     3) Read first frame only
;         IDL> f = file_search('\path\to\nascam\data\stream0.png\2010\01\01\fsmi_nascam-pmax01\ut06\*')
;         IDL> nascam_imager_readfile,f,img,meta,/first_frame
;
; EXTENDED EXAMPLES:
;     1) Using one file, watch frames as movie
;         IDL> filename = '20100101_0600_fsmi_nascam-pmax01.png.tar'
;         IDL> nascam_imager_readfile,filename,img,meta,COUNT=nframes
;         IDL> for i=0,nframes-1 DO tvscl,images[*,*,i]
;
;     2) Using 1 hour of data, display as keogram
;         IDL> f = file_search('\path\to\nascam\data\stream0.png\2010\01\01\fsmi_nascam-pmax01\ut06\*')
;         IDL> nascam_imager_readfile,f,img,meta,COUNT=nframes,/verbose
;         IDL> keogram = transpose(total(img[96:159,*,*],1))
;         IDL> tvscl,keogram,ORDER=1
;
; NOTES:
;     This code was based on Brian Jackel's "themis_imager_readfile" routine
;     written in 2006. The PGM format is described on the NetPBM home page
;     at http://netpbm.sourceforge.net/doc/pgm.html.
;
; MODIFICATION HISTORY:
;     2022-05-12: Darren Chaddock - creation based on trex_imager_readfile
;
;------------------------
; MIT License
;
; Copyright (c) 2022 University of Calgary
;
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included in all
; copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
; SOFTWARE.
;------------------------

; definition for the PNG metadata fields
pro nascam_imager_png_metadata__define
  compile_opt HIDDEN
  dummy = {$
    nascam_imager_png_metadata,$
    site_uid: '',$
    device_uid: '',$
    mode_uid: '',$
    exposure_start_string: '',$
    exposure_start_cdf: 0.0d0,$
    exposure_duration_request: 0.0$
  }
end

pro __nascam_cleanup_tar_files,file_list,VERBOSE=verbose
  ; for each file
  if (verbose eq 2) then print,'  Cleaning up untarred files'
  for i=0,n_elements(file_list)-1 do begin
    ; remove file
    file_delete,file_list[i],/ALLOW_NONEXISTENT
  endfor
end

function __nascam_png_readfile,filename,image_data,meta_data,dimension_details,n_frames,n_bytes,untar_extract_supported,idl_version_full_support,UNTAR_DIR=untar_dir,NO_UNTAR_CLEANUP=no_untar_cleanup,VERBOSE=verbose,FIRST_FRAME=first_frame
  ; init
  compile_opt HIDDEN
  n_frames = 0
  n_bytes = 0
  file_list = []
  cleanup_list = []
  dimension_details = [0, 0]

  ; check if file is tarred
  if (stregex(strupcase(filename),'.*\.TAR$',/BOOLEAN) eq 1) then begin
    ; file is tarred, need to untar it then process each frame
    if (verbose eq 2) then print,'  Untarring tarball: ' + filename
    if (first_frame ne 0) then begin
      ; check that we can do this based on the IDL version
      if (untar_extract_supported eq 0) then begin
        ; file_untar,/extract is not supported --> extract all files
        file_untar,filename,untar_dir,FILES=untarred_files
        file_list = untarred_files[sort(untarred_files)]
        file_list = file_list[0]
        cleanup_list = untarred_files
      endif else begin
        ; get list of files in tarball
        file_untar,filename,/list,FILES=tar_contents
        if (n_elements(tar_contents) gt 0) then begin
          ; extract just the first one
          tar_contents = tar_contents[sort(tar_contents)]
          file_untar,filename,untar_dir,EXTRACT_FILES=tar_contents[0],FILES=untarred_files
          file_list = [file_list, untarred_files]
          cleanup_list = untarred_files
        endif else begin
          print,'Error - tar file empty'
          goto,ioerror
        endelse
      endelse
    endif else begin
      ; extract all files
      file_untar,filename,untar_dir,FILES=untarred_files
      file_list = [file_list, untarred_files]
      cleanup_list = untarred_files
    endelse
  endif else begin
    ; file is just a png, add to list of files to read
    file_list = [file_list, filename]
    cleanup_list = []
  endelse

  ; for each file
  for i=0,n_elements(file_list)-1 do begin
    ; read png file
    if (verbose eq 2) then print,'  Processing frame: ' + file_basename(file_list[i])
    read_png,file_list[i],frame_img

    ; set dimensions
    image_size = size(frame_img,/STRUCT)
    frame_info = file_info(file_list[i])
    width = image_size.dimensions[0]
    height = image_size.dimensions[1]
    n_bytes = n_bytes + frame_info.size
    dimension_details = [width,height,image_size.type]

    ; re-orient
    frame_img[*,*] = reform(reverse(reform(frame_img[*,*]), 2), [width, height])

    ; allocate memory for image data and metadata if this is the first frame
    if (n_frames eq 0) then begin
      image_data = make_array([width,height,n_elements(file_list)],TYPE=image_size.type,/NOZERO)
      meta_data = replicate({nascam_imager_png_metadata},n_elements(file_list))
    endif

    ; set metadata
    frame_metadata = {nascam_imager_png_metadata}
    basename = file_basename(file_list[i])
    basename_split = strsplit(basename,'_',/extract)
    year = fix(strmid(basename_split[0], 0, 4))
    month = fix(strmid(basename_split[0], 4, 2))
    day = fix(strmid(basename_split[0], 6, 2))
    hour = fix(strmid(basename_split[1], 0, 2))
    minute = fix(strmid(basename_split[1], 2, 2))
    second = fix(strmid(basename_split[1], 4, 2))
    frame_metadata.site_uid = basename_split[2]
    frame_metadata.device_uid = basename_split[3]
    frame_metadata.exposure_duration_request = float(strmid(basename_split[5],0,strlen(basename_split[5])-6)) / 1000.0
    frame_metadata.mode_uid = basename_split[4]
    frame_metadata.exposure_start_string = '' + strmid(basename_split[0],0,4) + $
      '-' + strmid(basename_split[0],4,2) + '-' + strmid(basename_split[0],6,2) + $
      ' ' + strmid(basename_split[1],0,2) + ':' + strmid(basename_split[1],2,2) + $
      ':' + strmid(basename_split[1],4,2) + ' utc'

    ; set exposure cdf metadata field
    cdf_epoch,epoch,year,month,day,hour,minute,second,/COMPUTE
    frame_metadata.exposure_start_cdf = epoch

    ; append to image data array
    image_data[0,0,n_frames] = frame_img

    ; append to metadata array
    meta_data[n_frames] = frame_metadata

    ; increment number of frames
    n_frames += 1
  endfor

  ; remove extra unused memory
  if (n_frames gt 0 and n_frames lt n_elements(file_list)) then begin
    image_data = image_data[*,*,0:n_frames-1]
    meta_data = meta_data[0:n_frames-1]
  endif

  ; cleanup untarred files
  if (no_untar_cleanup eq 0) then __nascam_cleanup_tar_files,cleanup_list,VERBOSE=verbose
  return,0

  ; on error, remove extra unused memory, cleanup files, and return
  ioerror:
  print,'Error - could not process PNG file'
  if (n_frames gt 0) then begin
    image_data = image_data[*,*,0:n_frames-1]
    meta_data = meta_data[0:n_frames-1]
  endif
  if (no_untar_cleanup eq 0) then __nascam_cleanup_tar_files,cleanup_list,VERBOSE=verbose
  return,1
end

pro nascam_imager_readfile,filename,images,metadata,COUNT=n_frames,VERBOSE=verbose,VERY_VERBOSE=very_verbose,SHOW_DATARATE=show_datarate,ASSUME_EXISTS=assume_exists,FIRST_FRAME=first_frame,UNTAR_DIR=untar_dir,NO_UNTAR_CLEANUP=no_untar_cleanup
  ; init
  stride = 0
  time0 = systime(1)
  filenames = ''
  n_files = 0
  first_call = 1
  n_frames = 0
  n_bytes = 0
  _n_frames = 0
  idl_version_minimum = '8.2.3'
  idl_version_full_support = '8.7.1'
  untar_extract_supported = 1

  ; set keyword flags
  if (n_elements(assume_exists) eq 0) then assume_exists = 0
  if (n_elements(show_datarate) eq 0) then show_datarate = 0
  if (n_elements(first_frame) eq 0) then first_frame = 0
  if (n_elements(no_untar_cleanup) eq 0) then no_untar_cleanup = 0

  ; set verbosity
  if (n_elements(verbose) eq 0) then verbose = 0
  if (n_elements(very_verbose) eq 0) then very_verbose = 0
  if (very_verbose ne 0) then verbose = 2

  ; check IDL version
  idl_version = !version.release
  idl_version_split = strsplit(idl_version,'.',/extract)
  idl_version_major = fix(idl_version_split[0])
  idl_version_minor = fix(idl_version_split[1])
  idl_version_micro = fix(idl_version_split[2])
  if (idl_version_major le 7) then begin
    ; too old of a release
    print,'Error - IDL version below 8.2.3 is not supported. You are using version ' + idl_version
    return
  endif else if (idl_version_major eq 8 and idl_version_minor eq 2 and idl_version_micro eq 3) then begin
    ; minimum supported release
    if (verbose eq 2) then print,'Using minimum supported IDL version of 8.2.3, consider upgrading to ' + idl_version_full_support + '+ for all features'
    untar_extract_supported = 0
  endif else if (idl_version_major eq 8 and idl_version_minor le 6) then begin
    ; untarring with /first_frame not supported
    if (verbose eq 2) then begin
      print,'Info - Using IDL version ' + idl_version + ' instead of ' + idl_version_full_support + '+. This version is not fully supported, but, will work for almost all tasks'
    endif
    untar_extract_supported = 0
  endif

  ; set untar directory
  if (n_elements(untar_dir) eq 0) then begin
    ; path not supplied, use default based on OS
    case strlowcase(!version.os_family) of
      'unix': untar_dir = '~/nascam_imager_readfile_working'
      'windows': untar_dir = 'C:\nascam_imager_readfile_working'
    endcase
  endif else begin
    last_char = strmid(untar_dir,strlen(untar_dir)-1)
    if (last_char eq '/' or last_char eq '\') then begin
      untar_dir = strmid(untar_dir,0,strlen(untar_dir)-1)
    endif
  endelse

  ; init error catching
  catch,error
  if error ne 0 then begin
    print, 'Error: ',!error_state.msg
    return
    catch,/CANCEL
  endif

  ; check if files exist
  if (assume_exists eq 0) then begin
    ; for each filename, check that it exists and is readable
    for i=0,n_elements(filename)-1 do begin
      ; check if file exists and is readable
      file_ok = file_test(filename[i],/READ)
      if (file_ok gt 0) then filenames = [filenames,filename[i]]
    endfor
    n_files = n_elements(filenames)-1
    if (n_files eq 0) then begin
      message,'Error - files not found:' + filename[0],/INFORMATIONAL
      n_frames = 0
      return
    endif
    filenames = filenames[1:n_files]
  endif else begin
    if (n_elements(filename) eq 1) then begin
      filenames = [filename]
    endif
    n_files = n_elements(filenames)
  endelse

  ; sort filenames
  if (n_elements(filenames) gt 1) then filenames = filenames[sort(filenames)]
  if (verbose gt 0) then print,n_elements(filenames),format='("Found ",I," files")'

  ; set values for pre-allocating memory (significantly increases speed)
  n_chunk = 20
  if (stride ne 0) then begin
    n_start = (n_chunk * n_files / stride) < 2400
  endif else begin
    n_start = (n_chunk * n_files) < 2400
  endelse

  ; for each file
  total_expected_frames = 0
  for i=0,n_files-1 do begin
    ; set up error handler
    if (verbose gt 0) then print,' Reading file: ' + filenames[i]
    on_ioerror,fail

    ; process the file(s)
    ret = __nascam_png_readfile(filenames[i],file_images,file_metadata,file_dimension_details,file_nframes,file_total_bytes,untar_extract_supported,idl_version_full_support,UNTAR_DIR=untar_dir,NO_UNTAR_CLEANUP=no_untar_cleanup,VERBOSE=verbose,FIRST_FRAME=first_frame)

    ; set images and metadata array
    if (first_call eq 1) then begin
      ; pre-allocate images if it's the first call and we'll be reading more than one file
      if (n_files gt 1) then begin
        ; more than one file will be read, pre-allocate array for all images anticipated to be read in
        total_expected_frames = n_files * file_nframes  ; assume they are all tarballs, array will be trimmed at end
        images = make_array([file_dimension_details[0],file_dimension_details[1],total_expected_frames],TYPE=file_dimension_details[2],/NOZERO)

        ; insert images
        images[0,0,0] = file_images[*,*,*]
        metadata = file_metadata
      endif else begin
        ; first call, keep the same images and metadata
        images = file_images
        metadata = file_metadata
      endelse

      ; update first call flag
      first_call = 0
    endif else begin
      ; not the first call, check if the array needs to be expanded
      if ((n_frames+file_nframes) ge total_expected_frames) then begin
        ; need to expand the array
        total_expected_frames = total_expected_frames * 2
        images_new = make_array([file_dimension_details[0],file_dimension_details[1],total_expected_frames],TYPE=file_dimension_details[2],/NOZERO)
        images_new[0,0,0] = images[*,*,*]
        images = images_new
      endif

      ; add in new image data and metadata
      images[0,0,n_frames] = file_images[*,*,*]
      metadata = [metadata,file_metadata]
    endelse

    ; increment number of overall frames and increase n_bytes
    n_frames = n_frames + file_nframes
    n_bytes = n_bytes + file_total_bytes

    ; failure point, free the lun
    fail:
    if (isa(lun) eq 1) then free_lun,lun
  endfor

  ; remove extra unused memory
  images = images[*,*,0:n_frames-1]
  metadata = metadata[0:n_frames-1]

  ; show read timing information if verbose keyword is set
  if (show_datarate gt 0) then begin
    dtime = (systime(1) - time0) > 1
    i = 0
    while (n_bytes gt 1024L) do begin
      n_bytes = n_bytes / 1024.0
      i = i + 1
    endwhile
    prefix = (['','K','M','G','T'])[i]
    infoline = string(n_bytes,prefix,dtime,8*n_bytes/dtime,prefix,format='("Read ",F6.1,X,A,"B in ",I," seconds: ",F7.1,X,A,"b/second")')
    print,strcompress(infoline)
  endif
  skip: return
end