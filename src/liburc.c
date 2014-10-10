#include <Python.h>
#include "liburc.h"

/* security: enforce compatibility and santize malicious configurations */
#if crypto_sign_SECRETKEYBYTES != 64
exit(255);
#endif
#if crypto_sign_PUBLICKEYBYTES != 32
exit(255);
#endif
#if crypto_sign_BYTES != 64
exit(255);
#endif

#define URC_MTU_MASK 1023
#define IRC_MTU_MASK 511

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
 if (bsize > IRC_MTU_MASK) return Py_BuildValue("i", -1);
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
 if (bsize > IRC_MTU_MASK) return Py_BuildValue("i", -1);
 if (urcsign_fmt(p,b,bsize,sk) == -1) return Py_BuildValue("i", -1);
 return PyBytes_FromStringAndSize((char *)p, 2+12+4+8+bsize+64);
}

PyObject *pyurcsign_verify(PyObject *self, PyObject *args, PyObject *kw){
 static const char *kwlist[] = {"p", "pk", 0};
 unsigned char *p, *pk;
 Py_ssize_t psize=0, pksize=0;
 if ((!PyArg_ParseTupleAndKeywords(
  args,
  kw,
  "|s#s#:urcsign_verify",
  (char **)kwlist,
  (char **)&p,
  &psize,
  (char **)&pk,
  &pksize
 )) || (pksize != 32)) return Py_BuildValue("i", -1);
 if (urcsign_verify(p,psize,pk) == -1) return Py_BuildValue("i", -1);
 return Py_BuildValue("i", 0);
}

PyObject *pyurcsecretbox_fmt(PyObject *self, PyObject *args, PyObject *kw) {
 unsigned char p[2+12+4+8+1024+16]; 
 unsigned char m[1024*2];
 unsigned char c[1024*2];
 char *b;
 char *sk;
 Py_ssize_t bsize = 0;
 Py_ssize_t sksize = 0;
 static const char *kwlist[] = {"b","sk",0};
 bzero(m,32); /* http://nacl.cr.yp.to/secretbox.html */
 bzero(c,16);
 if ((!PyArg_ParseTupleAndKeywords(
  args,
  kw,
  "|s#s#:urcsecretbox_fmt",
  (char **)kwlist,
  &b,
  &bsize,
  &sk,
  &sksize
 )) || (sksize != 32)) return Py_BuildValue("i", -1);
 if (bsize > IRC_MTU_MASK) return Py_BuildValue("i", -1);
 if (urcsecretbox_fmt(p,b,bsize,sk) == -1) return Py_BuildValue("i", -1);
 return PyBytes_FromStringAndSize((char *)p, 2+12+4+8+bsize+16);
}

/* ImportError: workaround dummy init function (initliburc) */
PyObject *pyliburc(PyObject *self) { return Py_BuildValue("i", 0); }

static PyMethodDef Module_methods[] = {
 { "liburc",           pyliburc,           METH_NOARGS },
 { "urchub_fmt",       pyurchub_fmt,       METH_VARARGS|METH_KEYWORDS},
 { "urcsign_fmt",      pyurcsign_fmt,      METH_VARARGS|METH_KEYWORDS},
 { "urcsign_verify",   pyurcsign_verify,   METH_VARARGS|METH_KEYWORDS},
 { "urcsecretbox_fmt", pyurcsecretbox_fmt, METH_VARARGS|METH_KEYWORDS},
 { NULL, NULL}
};

void initliburc(){ (void) Py_InitModule("liburc", Module_methods); }
void initurchub_fmt(){ (void) Py_InitModule("urchub_fmt", Module_methods); }
void initurcsign_fmt(){ (void) Py_InitModule("urcsign_fmt", Module_methods); }
void initurcsign_verify(){ (void) Py_InitModule("urcsign_verify", Module_methods); }
void initurcsecretbox_fmt(){ (void) Py_InitModule("urcsecretbox_fmt", Module_methods); }
