#cython:language_level = 3

from intdict cimport fnv

from libc.stdint cimport uint16_t
from cpython.object cimport PyObject


cdef struct u16_pair_t:
    PyObject* value
    fnv.Fnv32_t hash
    uint16_t key

# Multidict uses 29 keys by default which is about the  
cdef struct u16_pair_list:
    Py_ssize_t capacity
    Py_ssize_t size
    u16_pair_t* pairs
    # Largest is 43 keys but 29 is a good estimate for an average amount...
    u16_pair_t[29] buffer


cdef class u16dict:
    cdef:
        u16_pair_list list

    cdef object cget(self, uint16_t key, PyObject* replace)
    cpdef u16dictitems items(self)
    cpdef u16dictkeys keys(self)
    cpdef u16dictvalues values(self)


cdef class u16dictitems:
    cdef:
        u16_pair_list *list
        u16dict dict
        object __it

cdef class u16dictkeys:
    cdef:
        u16_pair_list *list
        u16dict dict
        object __it

cdef class u16dictvalues:
    cdef:
        u16_pair_list *list
        u16dict dict
        object __it