"""Debuggee side of <Leader>dv (lua/dap_image_view.lua), run inside codelldb's Python.

Dumps a HALCON image/region/tuple/dictionary or an OpenCV matrix held in a variable.

LLDB cannot call HALCON's C++ API by name: halconcpp.dll has no PDB and its exports are
MSVC-mangled, so `img.WriteImage(...)` ends in "Couldn't look up symbols". Every function
is therefore taken by its exact exported name from the module's symbol table and called
through a cast function pointer, with `this` as the first argument (the x64 convention; a
class returned by value takes a hidden result buffer as the second one).

Everything a request needs happens in one call of this module (one DAP round trip), with
expressions that hold only numeric addresses and builtin types, evaluated in the target's
context: naming functions or types, or using the frame's context, made LLDB search every
loaded module or import every type in scope, seconds per step in this application.
"""

import json
import os

import lldb

HALCON_DLL = "halconcpp.dll"

# exported names, from `dumpbin /exports halconcpp.dll` (HALCON 25.11)
EXPORTS = {
    "image_ctor": ("??0HImage@HalconCpp@@QEAA@XZ", "void*(*)(void*)"),
    # (Type, Width, Height, PixelPointer)
    "image_from_pointer": ("??0HImage@HalconCpp@@QEAA@PEBD_J1PEAX@Z", "void*(*)(void*, const char*, long long, long long, void*)"),
    "gen_image_interleaved": (
        "?GenImageInterleaved@HImage@HalconCpp@@QEAAXPEAXPEBD_J221222222@Z",
        "void(*)(void*, void*, const char*, long long, long long, long long, const char*,"
        " long long, long long, long long, long long, long long, long long)",
    ),
    # (Format, FillColor, FileName)
    "write_image": ("?WriteImage@HImage@HalconCpp@@QEBAXPEBD_J0@Z", "void(*)(void*, const char*, long long, const char*)"),
    "scale_image_max": ("?ScaleImageMax@HImage@HalconCpp@@QEBA?AV12@XZ", "void*(*)(void*, void*)"),
    "image_type": ("?GetImageType@HImage@HalconCpp@@QEBA?AVHTuple@2@XZ", "void*(*)(void*, void*)"),
    "smallest_rectangle1": (
        "?SmallestRectangle1@HRegion@HalconCpp@@QEBAXPEA_J000@Z",
        "void(*)(void*, long long*, long long*, long long*, long long*)",
    ),
    "region_to_bin": (
        "?RegionToBin@HRegion@HalconCpp@@QEBA?AVHImage@2@_J000@Z",
        "void*(*)(void*, void*, long long, long long, long long, long long)",
    ),
    "union1": ("?Union1@HRegion@HalconCpp@@QEBA?AV12@XZ", "void*(*)(void*, void*)"),
    # (Mode)
    "xld_to_region": ("?GenRegionContourXld@HXLDCont@HalconCpp@@QEBA?AVHRegion@2@PEBD@Z", "void*(*)(void*, void*, const char*)"),
    "obj_class": ("?GetObjClass@HObject@HalconCpp@@QEBA?AVHTuple@2@XZ", "void*(*)(void*, void*)"),
    "count_obj": ("?CountObj@HObject@HalconCpp@@QEBA_JXZ", "long long(*)(void*)"),
    "select_obj": ("?SelectObj@HObject@HalconCpp@@QEBA?AV12@_J@Z", "void*(*)(void*, void*, long long)"),
    "tuple_ctor": ("??0HTuple@HalconCpp@@QEAA@XZ", "void*(*)(void*)"),
    "tuple_to_string": ("?ToString@HTuple@HalconCpp@@QEBA?AVHString@2@XZ", "void*(*)(void*, void*)"),
    "tuple_sem_type": ("?TupleSemType@HTuple@HalconCpp@@QEBA?AV12@XZ", "void*(*)(void*, void*)"),
    "tuple_handle": ("?H@HTuple@HalconCpp@@QEBA?AVHHandle@2@XZ", "void*(*)(void*, void*)"),
    "string_from_chars": ("??0HString@HalconCpp@@QEAA@PEBD@Z", "void*(*)(void*, const char*)"),
    "string_text": ("?Text@HString@HalconCpp@@QEBAPEBDXZ", "const char*(*)(void*)"),
    "dict_from_handle": ("??0HDict@HalconCpp@@QEAA@AEBVHHandle@1@@Z", "void*(*)(void*, void*)"),
    # (GenParamName, GenParamValue)
    "dict_to_json": ("?DictToJson@HDict@HalconCpp@@QEBA?AVHString@2@PEBD0@Z", "void*(*)(void*, void*, const char*, const char*)"),
    # (HString GenParamName, HTuple Key)
    "dict_param": (
        "?GetDictParam@HDict@HalconCpp@@QEBA?AVHTuple@2@AEBVHString@2@AEBV32@@Z",
        "void*(*)(void*, void*, void*, void*)",
    ),
    "dict_object": ("?GetDictObject@HDict@HalconCpp@@QEBA?AVHObject@2@PEBD@Z", "void*(*)(void*, void*, const char*)"),
}

MAX_TEXT = 16 * 1024 * 1024

_addresses = {}  # (process id, export key) -> load address


class Failure(Exception):
    pass


def _process():
    return lldb.frame.GetThread().GetProcess()


def _target():
    return _process().GetTarget()


def _fn(key):
    """C++ text for the exported HALCON function `key`, as a callable pointer."""
    process_id = _process().GetProcessID()
    address = _addresses.get((process_id, key))
    if address is None:
        target = _target()
        name = EXPORTS[key][0]
        for module in target.module_iter():
            if module.GetFileSpec().GetFilename().lower() == HALCON_DLL:
                symbol = module.FindSymbol(name)
                if symbol.IsValid():
                    address = symbol.GetStartAddress().GetLoadAddress(target)
                break
        if not address or address == lldb.LLDB_INVALID_ADDRESS:
            raise Failure("%s is not loaded in this process, or does not export %s" % (HALCON_DLL, name))
        _addresses[(process_id, key)] = address
    return "((%s)0x%xULL)" % (EXPORTS[key][1], address)


def _run(code):
    """Evaluates C++ in the debuggee and returns its value as an unsigned integer."""
    options = lldb.SBExpressionOptions()
    options.SetLanguage(lldb.eLanguageTypeC_plus_plus)
    # a call into HALCON got "interrupted: breakpoint" otherwise
    options.SetIgnoreBreakpoints(True)
    options.SetUnwindOnError(True)
    # writing a large image, or the first HALCON call of the process, can take a while
    options.SetTimeoutInMicroSeconds(60 * 1000 * 1000)
    # LLDB runs the call on this thread alone and only lets the other threads run after a
    # "one thread" timeout, by default half the one above: a call waiting on another
    # thread (a lock, a worker) would sit frozen for 30 s first
    options.SetTryAllThreads(True)
    options.SetOneThreadTimeoutInMicroSeconds(1000 * 1000)
    value = _target().EvaluateExpression(code, options)
    error = value.GetError()
    # a void expression "fails" with this code although it ran
    if error.Fail() and error.GetError() != 0x1001:
        raise Failure(error.GetCString() or "the expression failed")
    return value.GetValueAsUnsigned(0)


def _attempt(code):
    """Runs C++ that may legitimately fail inside HALCON; True when it did not."""
    try:
        _run(code)
        return True
    except Failure:
        return False


def _scratch(size=64):
    """Zeroed memory in the debuggee for an object that must outlive one expression.
    Never freed: a few bytes per use, for the length of a debugging session."""
    error = lldb.SBError()
    address = _process().AllocateMemory(size, lldb.ePermissionsReadable | lldb.ePermissionsWritable, error)
    if error.Fail() or address in (0, lldb.LLDB_INVALID_ADDRESS):
        raise Failure("could not allocate memory in the process: %s" % error.GetCString())
    return address


def _text(address):
    if not address:
        raise Failure("HALCON returned no text (object not initialized?)")
    error = lldb.SBError()
    text = _process().ReadCStringFromMemory(address, MAX_TEXT, error)
    if error.Fail():
        raise Failure(error.GetCString())
    return text or ""


def _c_string(text):
    return '"%s"' % text.replace("\\", "\\\\").replace('"', '\\"')


def _pointer(address):
    return "(void*)0x%xULL" % address


def _locate(expr):
    """(type name, address) of the object `expr` names in the selected frame.

    Through the variables API first, the one the Scopes view reads with: in optimized
    code LLDB's C++ evaluator fails to take the address of variables that API shows fine,
    and `&(x)` is plain wrong for pointers. A value kept in registers has no address:
    its bytes are copied to fresh memory, enough for HALCON handles and cv::Mat headers,
    which are only read here.
    """
    frame = lldb.frame
    value = frame.GetValueForVariablePath(expr)
    if not value.IsValid():
        value = frame.EvaluateExpression(expr)  # not a variable path: a cast, a call...
    if not value.IsValid():
        raise Failure("could not evaluate %s" % expr)
    value_type = value.GetType()
    if value_type.IsPointerType() or value_type.IsReferenceType():
        value = value.Dereference()
    gone = "%s has no value at this point (%s): try it from another frame, or on a member or parameter"
    if value.GetError().Fail():
        raise Failure(gone % (expr, value.GetError().GetCString() or "optimized out"))
    # AddressOf, not GetLoadAddress: for a value in a register the latter returns the value
    address_of = value.AddressOf()
    if address_of.IsValid() and address_of.GetError().Success() and address_of.GetValueAsUnsigned() > 65535:
        return value.GetTypeName(), address_of.GetValueAsUnsigned()
    data = value.GetData()
    size = data.GetByteSize()
    error = lldb.SBError()
    raw = data.ReadRawData(error, 0, size) if size else None
    if not raw or error.Fail():
        raise Failure(gone % (expr, "no storage"))
    address = _scratch(max(size, 64))
    _process().WriteMemory(address, raw, error)
    if error.Fail():
        raise Failure(error.GetCString())
    return value.GetTypeName(), address


def _write_image(image, path):
    # BMP: lossless like PNG, but with no compression to pay. For a 5472x3648 color image
    # PNG took 3.8 s ("png fastest"; 21 s at the default level), BMP 0.7 s.
    return '%s(%s, "bmp", 0, %s);' % (_fn("write_image"), image, _c_string(path))


def _tuple_text(address):
    """HTuple::ToString of the tuple at `address`, e.g. `["a", "b"]` or `42`."""
    string = _scratch()
    return _text(_run("%s(%s, %s); (unsigned long long)%s(%s)"
                      % (_fn("tuple_to_string"), _pointer(address), _pointer(string), _fn("string_text"), _pointer(string))))


def _dump_image(address, path, note=None):
    if not _attempt(_write_image(_pointer(address), path) + " 0") or not os.path.exists(path):
        # BMP holds byte images only: a uint2, real, int... image (typical after
        # filtering, or from deep learning) is shown stretched to its own gray range
        scaled = _scratch()
        _attempt("%s(%s, %s); %s 0" % (_fn("scale_image_max"), _pointer(address), _pointer(scaled),
                                        _write_image(_pointer(scaled), path)))
        if not os.path.exists(path):
            type_tuple = _scratch()
            known = _attempt("%s(%s, %s); 0" % (_fn("image_type"), _pointer(address), _pointer(type_tuple)))
            raise Failure("HALCON could not write this image to a file%s"
                          % (" (pixel type %s)" % _tuple_text(type_tuple) if known else ""))
        note = "; ".join(filter(None, [note, "gray values stretched to fit 8 bits"]))
    return {"kind": "image", "note": note}


def _dump_region(address, path, note=None):
    # on a canvas just big enough for the region
    _run(" ".join([
        "void* region = %s;" % _pointer(address),
        "long long r1 = 0, c1 = 0, r2 = 0, c2 = 0;",
        "%s(region, &r1, &c1, &r2, &c2);" % _fn("smallest_rectangle1"),
        "char image[64];",
        "%s(region, image, 255, 0, c2 + 2, r2 + 2);" % _fn("region_to_bin"),
        _write_image("image", path),
        "0",
    ]))
    return {"kind": "image", "note": note}


def _dump_object(address, path, label):
    """An HObject can be images, regions, XLD contours...: ask HALCON which and how many."""
    count = _run("(unsigned long long)%s(%s)" % (_fn("count_obj"), _pointer(address)))
    if count == 0:
        raise Failure("%s is an empty object" % label)
    class_tuple = _scratch()
    _run("%s(%s, %s); 0" % (_fn("obj_class"), _pointer(address), _pointer(class_tuple)))
    object_class = _tuple_text(class_tuple)  # one name per element: `["region", "region"]`
    note = None
    if "image" in object_class:
        if count > 1:
            first = _scratch()
            _run("%s(%s, %s, 1); 0" % (_fn("select_obj"), _pointer(address), _pointer(first)))
            address, note = first, "the first of %d images" % count
        return _dump_image(address, path, note)
    if "xld_cont" in object_class:
        region = _scratch()
        _run('%s(%s, %s, "margin"); 0' % (_fn("xld_to_region"), _pointer(address), _pointer(region)))
        address, note = region, "%d XLD contour(s), drawn as outline" % count
    elif "region" not in object_class:
        raise Failure("%s holds %s: only images, regions and XLD contours can be shown" % (label, object_class))
    if count > 1:
        merged = _scratch()
        _run("%s(%s, %s); 0" % (_fn("union1"), _pointer(address), _pointer(merged)))
        address, note = merged, note or "%d regions, shown merged" % count
    return _dump_region(address, path, note)


def _dump_cv_mat(address, path):
    # The header is read from memory, by offset: no expression, no type lookup. Layout of
    # OpenCV 3 and 4: int flags, dims, rows, cols at 0, 4, 8, 12 and uchar* data at 16.
    process = _process()
    error = lldb.SBError()
    flags = process.ReadUnsignedFromMemory(address, 4, error)
    rows = process.ReadUnsignedFromMemory(address + 8, 4, error)
    cols = process.ReadUnsignedFromMemory(address + 12, 4, error)
    pixels = process.ReadPointerFromMemory(address + 16, error)
    if error.Fail():
        raise Failure(error.GetCString())
    depth, channels = flags & 7, ((flags >> 3) & 511) + 1  # CV_MAT_TYPE
    if rows == 0 or cols == 0 or pixels == 0:
        raise Failure("the cv::Mat is empty")
    if depth != 0 or channels not in (1, 3):
        raise Failure("only 8-bit cv::Mat with 1 or 3 channels is supported (this one: depth %d, %d channels)" % (depth, channels))
    if channels == 1:
        build = '%s(image, "byte", %d, %d, %s);' % (_fn("image_from_pointer"), cols, rows, _pointer(pixels))
    else:
        build = '%s(image); %s(image, %s, "bgr", %d, %d, -1, "byte", 0, 0, 0, 0, -1, 0);' % (
            _fn("image_ctor"), _fn("gen_image_interleaved"), _pointer(pixels), cols, rows)
    _run("char image[64]; %s %s 0" % (build, _write_image("image", path)))
    return {"kind": "image"}


def _dump_dict(address):
    # dict_to_json gives the tuples and the nested dictionaries; the keys and their data
    # types tell which entries hold iconic objects, which JSON cannot carry
    json_text, keys, types, keys_text, types_text, texts = (_scratch() for _ in range(6))
    dictionary = _pointer(address)
    _run(" ".join([
        '%s(%s, %s, "raise_error_if_content_not_serializable", "false");' % (_fn("dict_to_json"), dictionary, _pointer(json_text)),
        "char keys_name[64]; char types_name[64]; char no_key[64];",
        '%s(keys_name, "keys"); %s(types_name, "key_data_type"); %s(no_key);'
        % (_fn("string_from_chars"), _fn("string_from_chars"), _fn("tuple_ctor")),
        "%s(%s, %s, keys_name, no_key);" % (_fn("dict_param"), dictionary, _pointer(keys)),
        "%s(%s, %s, types_name, %s);" % (_fn("dict_param"), dictionary, _pointer(types), _pointer(keys)),
        "%s(%s, %s);" % (_fn("tuple_to_string"), _pointer(keys), _pointer(keys_text)),
        "%s(%s, %s);" % (_fn("tuple_to_string"), _pointer(types), _pointer(types_text)),
        "const char** out = (const char**)%s;" % _pointer(texts),
        "out[0] = %s(%s);" % (_fn("string_text"), _pointer(json_text)),
        "out[1] = %s(%s);" % (_fn("string_text"), _pointer(keys_text)),
        "out[2] = %s(%s);" % (_fn("string_text"), _pointer(types_text)),
        "0",
    ]))
    error = lldb.SBError()
    json_str, keys_str, types_str = (_text(_process().ReadPointerFromMemory(texts + 8 * i, error)) for i in range(3))
    return {"kind": "dict", "json": json_str, "keys": keys_str, "types": types_str, "address": address}


def _dump_tuple(address):
    # Code exported from HDevelop keeps a dictionary as an HTuple holding its handle, not as
    # an HDict: printed as a tuple it would only show the handle. Ask HALCON what the tuple
    # holds and open a dictionary handle as the dictionary it is (the first one, if several).
    semantic = _scratch()
    _run("%s(%s, %s); 0" % (_fn("tuple_sem_type"), _pointer(address), _pointer(semantic)))
    if "dict" not in _tuple_text(semantic):
        return {"kind": "text", "text": _tuple_text(address)}
    handle, dictionary = _scratch(), _scratch()
    _run("%s(%s, %s); %s(%s, %s); 0" % (_fn("tuple_handle"), _pointer(address), _pointer(handle),
                                        _fn("dict_from_handle"), _pointer(dictionary), _pointer(handle)))
    return _dump_dict(dictionary)


def _dump(type_name, address, path, label):
    if "HTuple" in type_name:
        return _dump_tuple(address)
    if "HDict" in type_name:
        return _dump_dict(address)
    if "HRegion" in type_name:
        return _dump_region(address, path)
    if "HImage" in type_name:
        return _dump_image(address, path)
    if "HObject" in type_name:
        return _dump_object(address, path, label)
    if "cv::Mat" in type_name:
        return _dump_cv_mat(address, path)
    raise Failure("don't know how to show a %s (HImage, HRegion, HObject, HTuple, HDict and cv::Mat are supported)" % type_name)


def _reply(result_path, work):
    """Writes what `work` returns, or why it failed, to `result_path` as JSON: the only
    channel back to Neovim, so it always gets written."""
    try:
        result = work()
        result["ok"] = True
    except Failure as failure:
        result = {"ok": False, "error": str(failure)}
    except Exception as error:
        result = {"ok": False, "error": "%s: %s" % (type(error).__name__, error)}
    with open(result_path, "w", encoding="utf-8") as output:
        json.dump(result, output)
    return "done"


def view(expr, image_path, result_path):
    """Dumps the variable or expression `expr` of the selected frame."""
    def work():
        type_name, address = _locate(expr)
        return _dump(type_name, address, image_path, expr)
    return _reply(result_path, work)


def view_at(type_name, address, image_path, result_path):
    """Dumps an object known only by its type name and address."""
    return _reply(result_path, lambda: _dump(type_name, address, image_path, "%s@0x%x" % (type_name, address)))


def view_dict_object(dict_address, key, image_path, result_path):
    """Dumps the iconic object stored under `key` in the dictionary at `dict_address`."""
    def work():
        handle = _scratch()
        _run("%s(%s, %s, %s); 0" % (_fn("dict_object"), _pointer(dict_address), _pointer(handle), _c_string(key)))
        return _dump_object(handle, image_path, key)
    return _reply(result_path, work)
