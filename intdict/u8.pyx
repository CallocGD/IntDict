#cython:language_level = 3
#cython:boundscheck=False

cimport cython

from libc.stdint cimport uint8_t
from cpython.exc cimport PyErr_NoMemory
from cpython.object cimport PyObject
from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free
from cpython.ref cimport Py_XDECREF, Py_INCREF, Py_DECREF
from cpython.long cimport PyLong_FromLong
from cpython.tuple cimport PyTuple_Pack

from libc.string cimport memcpy, memmove

# from fnv cimport fnv.Fnv32_t, fnv.FAKE_RECAST, fnv.REVERSE_FAKE_RECAST, fnv.FNV1_32_INIT, fnv.FNV1_ONCE
from intdict cimport fnv

# Inspired by multidict pair_list.h , should be sizeof 9 bits 
# What makes this faster than multidict? 

# - were using integers and not strings which means we can
# cut out a few steps such as identities from the pairs...

# - were saving memory over multidict which is already 
# faster than python's dictionary. and Int-Dict is even faster..



cdef struct u8_pair_t:
    PyObject* value
    fnv.Fnv32_t hash
    uint8_t key

# Multidict uses 29 keys by default which is about the  
cdef struct u8_pair_list:
    Py_ssize_t capacity
    Py_ssize_t size
    u8_pair_t* pairs
    # Largest is 43 keys but 29 is a good estimate for an average amount...
    u8_pair_t[29] buffer


cdef inline u8_pair_t* u8_pair_list_get(u8_pair_list* list, Py_ssize_t i):
    return list.pairs + i

cdef inline int u8_pair_list_grow(u8_pair_list* list):
    cdef Py_ssize_t new_capacity
    cdef u8_pair_t* new_pairs
    if (list.size < list.capacity):
        return 0
    
    if list.pairs == list.buffer:
        new_pairs = <u8_pair_t*>PyMem_Malloc(sizeof(u8_pair_t) * 63)
        if new_pairs == NULL:
            PyErr_NoMemory()
            return -1
        memcpy(new_pairs, list.buffer, <size_t>list.capacity * sizeof(u8_pair_t))
        list.pairs = new_pairs
        list.capacity = 63
        return 0
    else:
        new_capacity = list.capacity + 64
        new_pairs = <u8_pair_t*>PyMem_Realloc(list.pairs, sizeof(u8_pair_t) * new_capacity)
        if new_pairs == NULL:
            PyErr_NoMemory()
            return -1
        list.pairs = new_pairs
        list.capacity = new_capacity
        return 0

cdef inline int u8_pair_list_shrink(u8_pair_list* list):
    cdef Py_ssize_t new_capacity
    cdef u8_pair_t* new_pairs
    
    if (list.capacity - list.size < 2 * 64):
        return 0
    
    new_capacity = list.capacity - 64
    if new_capacity < 63:
        return 0
    
    new_pairs = <u8_pair_t*>PyMem_Realloc(list.pairs, sizeof(u8_pair_t) * new_capacity)
    if NULL == new_pairs:
        PyErr_NoMemory()
        return -1 
    
    list.pairs = new_pairs
    list.capacity = new_capacity
    return 0

cdef inline int u8_pair_list_init(u8_pair_list* list):
    list.pairs = list.buffer
    list.capacity = 29
    list.size = 0
    return 0

cdef inline int u8_pair_list_del_at(u8_pair_list* list, Py_ssize_t pos):
    cdef:
        Py_ssize_t tail
        u8_pair_t* pair = u8_pair_list_get(list, pos)

    pair.key = 0
    Py_DECREF(fnv.FAKE_RECAST(pair.value)) 

    list.size -= 1
    if list.size == pos:
        return 0
    
    tail = list.size - pos 

    memmove(<void*>u8_pair_list_get(list, pos),
        <void*>u8_pair_list_get(list, pos + 1),
        sizeof(u8_pair_t) * <size_t>tail)
    return u8_pair_list_shrink(list)


cdef inline int u8_pair_list_drop_tail(u8_pair_list* list, fnv.Fnv32_t hash, Py_ssize_t pos):
    cdef:
        u8_pair_t* pair 
        int ret 
        int found = 0
        Py_ssize_t n
    
    if pos >= list.size:
        return 0
    
    for n in range(pos, list.size):
        pair = list.pairs + n
        if pair.hash != hash:
            continue 

        if u8_pair_list_del_at(list, n) < 0:
            return -1
        found = 1
    return found
        



cdef inline void u8_pair_list_dealloc(u8_pair_list* list):
    cdef:
        u8_pair_t* pair 
        Py_ssize_t pos
    
    for pos in range(list.size):
        pair = list.pairs + pos
        Py_XDECREF(pair.value)
    
    list.size = 0 
    if list.pairs != list.buffer:
        PyMem_Free(list.pairs)
        list.pairs = list.buffer
        list.capacity = 29
    
cdef inline Py_ssize_t pair_list_len(u8_pair_list* list):
    return list.size

cdef inline int _u8_pair_list_add_with_hash(
    u8_pair_list* list,
    uint8_t key, 
    PyObject* value,
    fnv.Fnv32_t hash
):
    if u8_pair_list_grow(list) < 0:
        return -1
    
    cdef u8_pair_t* pair = u8_pair_list_get(list, list.size)

    # NOTE: Does not need incref since it's already in C 
    pair.key = key
    
    pair.value = value

    pair.hash = hash

    list.size += 1

    return 0 

cdef inline fnv.Fnv32_t fnv_hash(uint8_t key) noexcept:
    cdef fnv.Fnv32_t hash = fnv.FNV1_32_INIT
    fnv.FNV1_ONCE(key, hash)
    return hash

cdef inline int u8_pair_list_add(u8_pair_list* list, uint8_t key, PyObject* value):
    return _u8_pair_list_add_with_hash(list, key, value, fnv_hash(key))

cdef inline bint u8_pair_list_contains(u8_pair_list* list, uint8_t key):
    cdef fnv.Fnv32_t hash =  fnv_hash(key)
    cdef Py_ssize_t pos = 0
    cdef u8_pair_t* pair 
    

    for pos in range(list.size):
        pair = list.pairs + pos
        if pair.key == key:
            return 1
    return 0

cdef inline PyObject* pair_list_pop_item(u8_pair_list* list):
    cdef PyObject* ret
    cdef u8_pair_t* pair

    if list.size == 0:
        raise KeyError("empty intdict")

    pair = list.pairs + 0
    ret = fnv.REVERSE_FAKE_RECAST(PyTuple_Pack(2, pair.key, pair.value))
    if ret == NULL:
        return NULL
    
    if u8_pair_list_del_at(list, 0) < 0:
        return NULL

    return ret

cdef inline PyObject* u8_pair_list_pop_one(u8_pair_list* list, uint8_t key):
    cdef PyObject* ret
    cdef u8_pair_t* pair
    cdef Py_ssize_t pos
    cdef fnv.Fnv32_t hash 
    
    if list.size == 0:
        raise KeyError("empty intdict")

    hash = fnv_hash(key)

    for pos in range(list.size):
        pair = list.pairs + pos
        if pair.hash != hash:    
            continue 
        else:
            ret = pair.value
            if u8_pair_list_del_at(list, pos) < 0:
                return NULL

    return ret



cdef inline PyObject* u8_pair_list_get_one(u8_pair_list* list, uint8_t key):
    cdef fnv.Fnv32_t hash =  fnv_hash(key)
    cdef Py_ssize_t pos
    cdef u8_pair_t* pair
    cdef object value

    for pos in range(list.size):
        pair = list.pairs + pos
        if pair.hash != hash:    
            continue 
        else:
            value = fnv.FAKE_RECAST(pair.value)
            Py_INCREF(value)
            return fnv.REVERSE_FAKE_RECAST(value)

    return NULL

cdef inline u8_pair_list_update_iterable(u8_pair_list* list, object iterable):
    cdef object k, v
    
    for k, v in iter(iterable):
        # Dissallow cython from freaking out with Reverse Fake Recast
        u8_pair_list_add(list, <uint8_t>k, fnv.REVERSE_FAKE_RECAST(v))







@cython.no_gc_clear
cdef class u8dict:

    def __cinit__(self, **kwargs):
        u8_pair_list_init(&self.list)
        cdef object iterable
        if iterable := kwargs.get("iterable", None):
            u8_pair_list_update_iterable(&self.list, iterable)

    cdef object cget(self, uint8_t key, PyObject* replace):
        return fnv.FAKE_RECAST(u8_pair_list_get_one(&self.list, key))

    @cython.always_allow_keywords(False)    
    def get(self, *args):
        cdef PyObject* default = NULL
        cdef PyObject* result = NULL
        if len(args) > 1:
            default = fnv.REVERSE_FAKE_RECAST(args[1])
        
        result = u8_pair_list_get_one(&self.list, <uint8_t>args[0])
        if result == NULL:
            if default == NULL:
                raise KeyError(args[0])
            return fnv.FAKE_RECAST(default)
        return fnv.FAKE_RECAST(result)

    @cython.always_allow_keywords(False)
    def pop(self, *args):
        cdef PyObject* default = NULL
        cdef PyObject* result = NULL
        if len(args) > 1:
            default = fnv.REVERSE_FAKE_RECAST(args[1])
        
        result = u8_pair_list_pop_one(&self.list, <uint8_t>args[0])
        if result == NULL:
            if default == NULL:
                raise KeyError(args[0])
            return fnv.FAKE_RECAST(default)
        return fnv.FAKE_RECAST(result)

    @cython.always_allow_keywords(False)
    def __getitem__(self, key):
        return self.cget(<uint8_t>key, NULL)

    @cython.always_allow_keywords(False)
    def __setitem__(self, key, value):
        u8_pair_list_add(&self.list, key, fnv.REVERSE_FAKE_RECAST(value))        

    @cython.always_allow_keywords(False)
    def __delitem__(self, key):
        u8_pair_list_pop_one(&self.list, <uint8_t>key)
      
    def __dealloc__(self):
        if &self.list != NULL:
            u8_pair_list_dealloc(&self.list)

    cpdef u8dictitems items(self):
        return u8dictitems(self)

    cpdef u8dictkeys keys(self):
        return u8dictkeys(self)

    cpdef u8dictvalues values(self):
        return u8dictvalues(self)

    def __repr__(self) -> str:
        cdef u8dictitems i = self.items()
        body = ", ".join("{}: {!r}".format(k, v) for k, v in i)
        return "<{}({})>".format(self.__class__.__name__, body)



# These three are not meant to be subclassed with and are primarly for helping with the given iterables...
@cython.final
cdef class u8dictitems:

    def __cinit__(self, u8dict u8) -> None:
        self.list = &u8.list
        self.dict = u8
        self.__it = self.__iter()

    def __iter(self):
        cdef u8_pair_t* pair
        cdef Py_ssize_t pos
        cdef tuple ret 
        for pos in range(self.list.size):
            pair = &self.list.pairs[pos]
            if pair != NULL:
                ret  = (pair.key, fnv.FAKE_RECAST(pair.value))    
                yield ret

    def __iter__(self):
        cdef tuple ret
        for ret in self.__it:
            yield ret
    
    def __next__(self) -> tuple:
        return next(self.__it)

    def __len__(self):
        return self.list.size


@cython.final
cdef class u8dictvalues:

    def __cinit__(self, u8dict u8) -> None:
        self.list = &u8.list
        self.dict = u8
        self.__it = self.__iter()

    def __iter(self):
        cdef u8_pair_t* pair
        cdef Py_ssize_t pos
        for pos in range(self.list.size):
            pair = self.list.pairs + pos
            yield fnv.FAKE_RECAST(pair.value)    

    def __iter__(self):
        cdef tuple ret
        for ret in self.__it:
            yield ret
    
    def __next__(self) -> object:
        return next(self.__it)

    def __len__(self) -> int:
        return self.list.size

@cython.final
cdef class u8dictkeys:

    def __cinit__(self, u8dict u8) -> None:
        self.list = &u8.list
        self.dict = u8
        self.__it = self.__iter()

    def __iter(self):
        cdef u8_pair_t* pair
        cdef Py_ssize_t pos
        for pos in range(self.list.size):
            pair = self.list.pairs + pos
            yield PyLong_FromLong(pair.key)

    def __iter__(self):
        cdef tuple ret
        for ret in self.__it:
            yield ret
    
    def __next__(self) -> object:
        return next(self.__it)

    def __len__(self) -> int:
        return self.list.size
