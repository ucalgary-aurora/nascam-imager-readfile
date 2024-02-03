import os
import pytest
import numpy as np
import nascam_imager_readfile

# globals
DATA_DIR = "%s/data" % (os.path.dirname(os.path.realpath(__file__)))


@pytest.mark.parametrize("test_dict", [
    {
        "filename": "20090209_0600_gill_nascam-iccd02.png.tar",
        "expected_success": True,
        "expected_frames": 10
    },
    {
        "filename": "20090209_0601_gill_nascam-iccd02.png.tar",
        "expected_success": True,
        "expected_frames": 10
    },
    {
        "filename": "20090209_060501_gill_nascam-iccd02_5577_001000ms.png",
        "expected_success": True,
        "expected_frames": 1
    },
])
def test_read_single_file(test_dict):
    # read file
    img, meta, problematic_files = nascam_imager_readfile.read("%s/%s" % (DATA_DIR, test_dict["filename"]))

    # check success
    if (test_dict["expected_success"] is True):
        assert len(problematic_files) == 0
    else:
        assert len(problematic_files) > 0

    # check number of frames
    assert img.shape == (256, 256, test_dict["expected_frames"])
    assert len(meta) == test_dict["expected_frames"]

    # check dtype
    assert img.dtype == np.uint16


@pytest.mark.parametrize("test_dict", [
    {
        "filenames": [
            "20090209_0600_gill_nascam-iccd02.png.tar",
        ],
        "expected_success": True,
        "expected_frames": 10
    },
    {
        "filenames": [
            "20090209_060501_gill_nascam-iccd02_5577_001000ms.png",
        ],
        "expected_success": True,
        "expected_frames": 1
    },
    {
        "filenames": [
            "20090209_0600_gill_nascam-iccd02.png.tar",
            "20090209_0601_gill_nascam-iccd02.png.tar",
        ],
        "expected_success": True,
        "expected_frames": 20
    },
    {
        "filenames": [
            "20090209_0600_gill_nascam-iccd02.png.tar",
            "20090209_0601_gill_nascam-iccd02.png.tar",
            "20090209_060501_gill_nascam-iccd02_5577_001000ms.png",
        ],
        "expected_success": True,
        "expected_frames": 21
    },
    {
        "filenames": [
            "20090209_0600_gill_nascam-iccd02.png.tar",
            "20090209_0601_gill_nascam-iccd02.png.tar",
            "20090209_0602_gill_nascam-iccd02.png.tar",
            "20090209_0603_gill_nascam-iccd02.png.tar",
            "20090209_0604_gill_nascam-iccd02.png.tar",
        ],
        "expected_success": True,
        "expected_frames": 50
    },
])
def test_read_multiple_files(test_dict):
    # build file list
    file_list = []
    for f in test_dict["filenames"]:
        file_list.append("%s/%s" % (DATA_DIR, f))

    # read file
    img, meta, problematic_files = nascam_imager_readfile.read(file_list)

    # check success
    if (test_dict["expected_success"] is True):
        assert len(problematic_files) == 0
    else:
        assert len(problematic_files) > 0

    # check number of frames
    assert img.shape == (256, 256, test_dict["expected_frames"])
    assert len(meta) == test_dict["expected_frames"]

    # check that there's metadata
    for m in meta:
        assert len(m) > 0

    # check dtype
    assert img.dtype == np.uint16


@pytest.mark.parametrize("test_dict", [
    {
        "filename": "20090209_0600_gill_nascam-iccd02.png.tar",
        "workers": 1,
        "expected_success": True,
        "expected_frames": 10
    },
    {
        "filename": "20090209_0601_gill_nascam-iccd02.png.tar",
        "workers": 2,
        "expected_success": True,
        "expected_frames": 10
    },
])
def test_read_single_file_workers(test_dict):
    # read file
    img, meta, problematic_files = nascam_imager_readfile.read(
        "%s/%s" % (DATA_DIR, test_dict["filename"]),
        workers=test_dict["workers"],
    )

    # check success
    if (test_dict["expected_success"] is True):
        assert len(problematic_files) == 0
    else:
        assert len(problematic_files) > 0

    # check number of frames
    assert img.shape == (256, 256, test_dict["expected_frames"])
    assert len(meta) == test_dict["expected_frames"]

    # check that there's metadata
    for m in meta:
        assert len(m) > 0

    # check dtype
    assert img.dtype == np.uint16


@pytest.mark.parametrize("test_dict", [
    {
        "filenames": [
            "20090209_0600_gill_nascam-iccd02.png.tar",
        ],
        "workers": 1,
        "expected_success": True,
        "expected_frames": 10
    },
    {
        "filenames": [
            "20090209_0600_gill_nascam-iccd02.png.tar",
        ],
        "workers": 2,
        "expected_success": True,
        "expected_frames": 10
    },
    {
        "filenames": [
            "20090209_0600_gill_nascam-iccd02.png.tar",
            "20090209_0601_gill_nascam-iccd02.png.tar",
        ],
        "workers": 1,
        "expected_success": True,
        "expected_frames": 20
    },
    {
        "filenames": [
            "20090209_0600_gill_nascam-iccd02.png.tar",
            "20090209_0601_gill_nascam-iccd02.png.tar",
        ],
        "workers": 2,
        "expected_success": True,
        "expected_frames": 20
    },
    {
        "filenames": [
            "20090209_0600_gill_nascam-iccd02.png.tar",
            "20090209_0601_gill_nascam-iccd02.png.tar",
            "20090209_0602_gill_nascam-iccd02.png.tar",
            "20090209_0603_gill_nascam-iccd02.png.tar",
            "20090209_0604_gill_nascam-iccd02.png.tar",
        ],
        "workers": 1,
        "expected_success": True,
        "expected_frames": 50
    },
    {
        "filenames": [
            "20090209_0600_gill_nascam-iccd02.png.tar",
            "20090209_0601_gill_nascam-iccd02.png.tar",
            "20090209_0602_gill_nascam-iccd02.png.tar",
            "20090209_0603_gill_nascam-iccd02.png.tar",
            "20090209_0604_gill_nascam-iccd02.png.tar",
        ],
        "workers": 2,
        "expected_success": True,
        "expected_frames": 50
    },
    {
        "filenames": [
            "20090209_0600_gill_nascam-iccd02.png.tar",
            "20090209_0601_gill_nascam-iccd02.png.tar",
            "20090209_0602_gill_nascam-iccd02.png.tar",
            "20090209_0603_gill_nascam-iccd02.png.tar",
            "20090209_0604_gill_nascam-iccd02.png.tar",
        ],
        "workers": 5,
        "expected_success": True,
        "expected_frames": 50
    },
])
def test_read_multiple_files_workers(test_dict):
    # build file list
    file_list = []
    for f in test_dict["filenames"]:
        file_list.append("%s/%s" % (DATA_DIR, f))

    # read file
    img, meta, problematic_files = nascam_imager_readfile.read(
        file_list,
        workers=test_dict["workers"],
    )

    # check success
    if (test_dict["expected_success"] is True):
        assert len(problematic_files) == 0
    else:
        assert len(problematic_files) > 0

    # check number of frames
    assert img.shape == (256, 256, test_dict["expected_frames"])
    assert len(meta) == test_dict["expected_frames"]

    # check that there's metadata
    for m in meta:
        assert len(m) > 0

    # check dtype
    assert img.dtype == np.uint16
