from libc.stdint cimport uint32_t
from cpython.object cimport PyObject

cdef extern from *:
    """

#define FAKE_RECAST(obj) obj
#define REVERSE_FAKE_RECAST(obj) obj

#define FNV_32_PRIME (unsigned int)1000003UL /* Python Prime was replaced from the FNVPRime*/

#define FNV1_32_INIT (uint32_t)0x811c9dc5

/* MODIFED VERSION OF FNV LIBRARY FOR SINGLE INTEGERS */

typedef uint32_t Fnv32_t;

#ifdef __GNUC__ 
    #define FNV1_ONCE(i, hval) \\
        hval += (hval<<1) + (hval<<4) + (hval<<7) + (hval<<8) + (hval<<24); hval ^= (Fnv32_t) i;

#else
    #define FNV1_ONCE(i, hval) \\
        hval *= FNV_32_PRIME; hval ^= (uint32_t)i; 

#endif /* __GNUC__ */

    """

    # Only needed these functions, no more, no less...
    
    uint32_t FNV1_32_INIT

    # Bypass Cython's Checks so that we can make our dictionary work correctly.
    object FAKE_RECAST(PyObject*)
    PyObject* REVERSE_FAKE_RECAST(object)
    ctypedef uint32_t Fnv32_t

    void FNV1_ONCE(uint32_t i, uint32_t hval)

