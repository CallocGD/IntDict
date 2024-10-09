#cython:language_level = 3

from intdict cimport fnv

from libc.stdint cimport uint8_t
from cpython.object cimport PyObject


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


cdef class u8dict:
    cdef:
        u8_pair_list list

    cdef object cget(self, uint8_t key, PyObject* replace)
    cpdef u8dictitems items(self)
    cpdef u8dictkeys keys(self)
    cpdef u8dictvalues values(self)


cdef class u8dictitems:
    cdef:
        u8_pair_list *list
        u8dict dict
        object __it

cdef class u8dictkeys:
    cdef:
        u8_pair_list *list
        u8dict dict
        object __it

cdef class u8dictvalues:
    cdef:
        u8_pair_list *list
        u8dict dict
        object __it

