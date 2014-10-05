#include <Python.h>
#include "liburc.h"

/* security: enforce compatibility and santize malicious configurations */
#if crypto_sign_SECRETKEYBYTES != 64
exit(255);
#endif
#if crypto_sign_BYTES != 64
exit(255);
#endif

PyObject *pyurchub_fmt(PyObject *self, PyObject *args, PyObject *kw) {
  unsigned char p[2+12+4+8+1024];
  char *b;
  Py_ssize_t bsize = 0;
  static const char *kwlist[] = {"b",0};
  if (!PyArg_ParseTupleAndKeywords(
   args,
   kw,
   "|s#:urchub_fmt",
   (char **)kwlist,
   &b,
   &bsize
  )) return Py_BuildValue("i", -1);
  bsize &= 1023; /* security: prevent overflow */
  if (urchub_fmt(p,b,bsize) == -1) return Py_BuildValue("i", -1);
  return PyBytes_FromStringAndSize((char *)p, 2+12+4+8+bsize);
}

PyObject *pyurcsign_fmt(PyObject *self, PyObject *args, PyObject *kw) {
  unsigned char p[2+12+4+8+1024+64];
  char *b;
  char *sk;
  Py_ssize_t bsize = 0;
  Py_ssize_t sksize = 0;
  static const char *kwlist[] = {"b","sk",0};
  if ((!PyArg_ParseTupleAndKeywords(
   args,
   kw,
   "|s#s#:urcsign_fmt",
   (char **)kwlist,
   &b,
   &bsize,
   &sk,
   &sksize
  )) || (sksize != 64)) return Py_BuildValue("i", -1);
  bsize &= 1023; /* security: prevent overflow */
  if (urcsign_fmt(p,b,bsize,sk) == -1) return Py_BuildValue("i", -1);
  return PyBytes_FromStringAndSize((char *)p, 2+12+4+8+bsize+64);
}

/* hack __init__ */
PyObject *pyliburc(PyObject *self) { return Py_BuildValue("i", -1); }

static PyMethodDef Module_methods[] = {
 { "liburc",      pyliburc,      METH_NOARGS },
 { "urchub_fmt",  pyurchub_fmt,  METH_VARARGS|METH_KEYWORDS},
 { "urcsign_fmt", pyurcsign_fmt, METH_VARARGS|METH_KEYWORDS},
 { NULL, NULL}
};

void initliburc()      { (void) Py_InitModule("liburc",      Module_methods); }
void initurchub_fmt()  { (void) Py_InitModule("urchub_fmt",  Module_methods); }
void initurcsign_fmt() { (void) Py_InitModule("urcsign_fmt", Module_methods); }
