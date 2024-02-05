import signal
import cv2
import tarfile
import os
import datetime
import string
import random
import shutil
import numpy as np
from pathlib import Path
from multiprocessing import Pool

# static globals
__EXPECTED_FRAME_COUNT = 20
__PNG_METADATA_PROJECT_UID = "nascam"


def __nascam_readfile_worker(file_obj):
    # init
    images = np.array([])
    metadata_dict_list = []
    problematic = False
    error_message = ""
    image_width = 0
    image_height = 0
    image_dtype = np.dtype("uint16")
    image_dtype = image_dtype.newbyteorder('>')

    # check file extension to know how to process
    try:
        if (file_obj["filename"].endswith("png") or file_obj["filename"].endswith("png.tar")):
            return __nascam_readfile_worker_png(file_obj)
        else:
            if (file_obj["quiet"] is False):
                print("Unrecognized file type: %s" % (file_obj["filename"]))
    except Exception as e:
        if (file_obj["quiet"] is False):
            print("Failed to process file '%s' " % (file_obj["filename"]))
        problematic = True
        error_message = "failed to process file: %s" % (str(e))
    return images, metadata_dict_list, problematic, file_obj["filename"], error_message, \
        image_width, image_height, image_dtype


def __nascam_readfile_worker_png(file_obj):
    # init
    images = np.array([])
    metadata_dict_list = []
    problematic = False
    is_first = True
    error_message = ""
    image_width = 0
    image_height = 0
    image_dtype = np.uint16
    working_dir_created = False

    # set up working dir
    this_working_dir = "%s/%s" % (file_obj["tar_tempdir"], ''.join(random.choices(string.ascii_lowercase, k=8)))

    # check if it's a tar file
    file_list = []
    if (file_obj["filename"].endswith(".png.tar")):
        # tar file, extract all frames and add to list
        try:
            tf = tarfile.open(file_obj["filename"])
            file_list = sorted(tf.getnames())
            tf.extractall(path=this_working_dir)
            for i in range(0, len(file_list)):
                file_list[i] = "%s/%s" % (this_working_dir, file_list[i])
            tf.close()
            working_dir_created = True
        except Exception as e:
            # cleanup
            try:
                shutil.rmtree(this_working_dir)
            except Exception:
                pass

            # set error message
            if (file_obj["quiet"] is False):
                print("Failed to open file '%s' " % (file_obj["filename"]))
            problematic = True
            error_message = "failed to open file: %s" % (str(e))
            try:
                tf.close()
            except Exception:
                pass
            return images, metadata_dict_list, problematic, file_obj["filename"], error_message, \
                image_width, image_height, image_dtype
    else:
        # regular png
        file_list = [file_obj["filename"]]

    # read each png file
    for f in file_list:
        # process metadata
        try:
            # set metadata values
            file_split = os.path.basename(f).split('_')
            site_uid = file_split[2]
            device_uid = file_split[3]
            mode_uid = file_split[4]
            exposure = "%.03f ms" % (float(file_split[5][:-6]))
            timestamp = datetime.datetime.strptime("%sT%s" % (file_split[0], file_split[1]), "%Y%m%dT%H%M%S")

            # set the metadata dict
            metadata_dict = {
                "Project unique ID": __PNG_METADATA_PROJECT_UID,
                "Site unique ID": site_uid,
                "Imager unique ID": device_uid,
                "Mode unique ID": mode_uid,
                "Image request start": timestamp,
                "Subframe requested exposure": exposure,
            }
            metadata_dict_list.append(metadata_dict)
        except Exception as e:
            if (file_obj["quiet"] is False):
                print("Failed to read metadata from file '%s' " % (f))
            problematic = True
            error_message = "failed to read metadata: %s" % (str(e))
            break

        # read png file
        try:
            # read file
            image_np = cv2.imread(f, cv2.IMREAD_UNCHANGED)
            image_width = image_np.shape[0]
            image_height = image_np.shape[1]
            image_matrix = np.reshape(image_np, (image_width, image_height, 1))

            # initialize image stack
            if (is_first is True):
                images = image_matrix
                is_first = False
            else:
                images = np.dstack([images, image_matrix])  # depth stack images (on last axis)
        except Exception as e:
            if (file_obj["quiet"] is False):
                print("Failed reading image data frame: %s" % (str(e)))
            metadata_dict_list.pop()  # remove corresponding metadata entry
            problematic = True
            error_message = "image data read failure: %s" % (str(e))
            continue  # skip to next frame

    # cleanup
    #
    # NOTE: we only clean up the working dir if we created it
    if (working_dir_created is True):
        shutil.rmtree(this_working_dir)

    # return
    return images, metadata_dict_list, problematic, file_obj["filename"], error_message, \
        image_width, image_height, image_dtype


def read(file_list, workers=1, tar_tempdir=None, quiet=False):
    """
    Read in a single PNG.TAR file, or an array of them. All files
    must be the same type.

    :param file_list: filename or list of filenames
    :type file_list: str
    :param workers: number of worker processes to spawn, defaults to 1
    :type workers: int, optional
    :param tar_tempdir: path to untar to, defaults to '~/.nascam_imager_readfile'
    :type tar_tempdir: str, optional
    :param quiet: reduce output while reading data
    :type quiet: bool, optional

    :return: images, metadata dictionaries, and problematic files
    :rtype: numpy.ndarray, list[dict], list[dict]
    """
    # set tar path
    if (tar_tempdir is None):
        tar_tempdir = Path("%s/.nascam_imager_readfile" % (str(Path.home())))
    os.makedirs(tar_tempdir, exist_ok=True)

    # if input is just a single file name in a string, convert to a list to be fed to the workers
    if isinstance(file_list, str):
        file_list = [file_list]

    # convert to object, injecting other data we need for processing
    processing_list = []
    for f in file_list:
        processing_list.append({
            "filename": f,
            "tar_tempdir": tar_tempdir,
            "quiet": quiet,
        })

    # check workers
    if (workers > 1):
        try:
            # set up process pool (ignore SIGINT before spawning pool so child processes inherit SIGINT handler)
            original_sigint_handler = signal.signal(signal.SIGINT, signal.SIG_IGN)
            pool = Pool(processes=workers)
            signal.signal(signal.SIGINT, original_sigint_handler)  # restore SIGINT handler
        except ValueError:
            # likely the read call is being used within a context that doesn't support the usage
            # of signals in this way, proceed without it
            pool = Pool(processes=workers)

        # call readfile function, run each iteration with a single input file from file_list
        # NOTE: structure of data - data[file][metadata dictionary lists = 1, images = 0][frame]
        pool_data = []
        try:
            pool_data = pool.map(__nascam_readfile_worker, processing_list)
        except KeyboardInterrupt:
            pool.terminate()  # gracefully kill children
            return np.empty((0, 0, 0)), [], []
        else:
            pool.close()
            pool.join()
    else:
        # don't bother using multiprocessing with one worker, just call the worker function directly
        pool_data = []
        for p in processing_list:
            pool_data.append(__nascam_readfile_worker(p))

    # set sizes
    image_width = pool_data[0][5]
    image_height = pool_data[0][6]
    image_dtype = pool_data[0][7]

    # pre-allocate array sizes (optimization)
    predicted_num_frames = len(processing_list) * __EXPECTED_FRAME_COUNT
    images = np.empty([image_width, image_height, predicted_num_frames], dtype=image_dtype)
    metadata_dict_list = [{}] * predicted_num_frames
    problematic_file_list = []

    # reorganize data
    list_position = 0
    for i in range(0, len(pool_data)):
        # check if file was problematic
        if (pool_data[i][2] is True):
            problematic_file_list.append({
                "filename": pool_data[i][3],
                "error_message": pool_data[i][4],
            })

        # check if any data was read in
        if (len(pool_data[i][1]) == 0):
            continue

        # find actual number of frames, this may differ from predicted due to dropped frames, end
        # or start of imaging
        real_num_frames = pool_data[i][0].shape[-1]

        # metadata dictionary list at data[][1]
        metadata_dict_list[list_position:list_position + real_num_frames] = pool_data[i][1]
        images[:, :, list_position:list_position + real_num_frames] = pool_data[i][0]
        list_position = list_position + real_num_frames  # advance list position

    # trim unused elements from predicted array sizes
    metadata_dict_list = metadata_dict_list[0:list_position]
    images = np.delete(images, range(list_position, predicted_num_frames), axis=2)

    # ensure entire array views as the dtype
    images = images.astype(image_dtype)

    # return
    pool_data = None
    return images, metadata_dict_list, problematic_file_list
