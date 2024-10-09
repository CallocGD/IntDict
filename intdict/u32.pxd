#cython:language_level = 3

from intdict cimport fnv

from libc.stdint cimport uint32_t
from cpython.object cimport PyObject


cdef struct int_pair_t:
    PyObject* value
    fnv.Fnv32_t hash
    uint32_t key

# Multidict uses 29 keys by default which is about the  
cdef struct int_pair_list:
    Py_ssize_t capacity
    Py_ssize_t size
    int_pair_t* pairs
    # Largest is 43 keys but 29 is a good estimate for an average amount...
    int_pair_t[29] buffer



cdef class IntDict:
    cdef:
        int_pair_list list

    cdef object cget(self, uint32_t key, PyObject* replace)
    cpdef IntDictItems items(self)
    cpdef IntDictKeys keys(self)
    cpdef IntDictValues values(self)
    

cdef class IntDictProxy(IntDict):
    cdef:
        object __weakref__ 


cdef class IntDictItems:
    cdef:
        int_pair_list *list
        IntDict dict
        object __it

cdef class IntDictValues:
    cdef:
        int_pair_list *list
        IntDict dict
        object __it

cdef class IntDictKeys:
    cdef:
        int_pair_list *list
        IntDict dict
        object __it
