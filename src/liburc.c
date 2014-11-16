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

#define URC_MTU 1024
#define IRC_MTU 512

PyObject *pyurchub_fmt(PyObject *self, PyObject *args, PyObject *kw) {
 unsigned char p[1024];
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
 if (bsize > IRC_MTU) return Py_BuildValue("i", -1);
 if (urchub_fmt(p,b,bsize) == -1) return Py_BuildValue("i", -1);
 return PyBytes_FromStringAndSize((char *)p, 2+12+4+8+bsize);
}

PyObject *pyurcsign_fmt(PyObject *self, PyObject *args, PyObject *kw) {
 unsigned char p[1024];
 char *b;
 char *sk;
 Py_ssize_t bsize = 0;
 Py_ssize_t sksize = 0;
 static const char *kwlist[] = {"b","sk",0};
 if (!PyArg_ParseTupleAndKeywords(
  args,
  kw,
  "|s#s#:urcsign_fmt",
  (char **)kwlist,
  &b,
  &bsize,
  &sk,
  &sksize
 )) return Py_BuildValue("i", -1);
 if (sksize != 64) return Py_BuildValue("i", -1);
 if (bsize > IRC_MTU) return Py_BuildValue("i", -1);
 if (urcsign_fmt(p,b,bsize,sk) == -1) return Py_BuildValue("i", -1);
 return PyBytes_FromStringAndSize((char *)p, 2+12+4+8+bsize+64);
}

PyObject *pyurcsign_verify(PyObject *self, PyObject *args, PyObject *kw) {
 unsigned char *p;
 unsigned char *pk;
 Py_ssize_t psize=0, pksize=0;
 static const char *kwlist[] = {"p", "pk", 0};
 if (!PyArg_ParseTupleAndKeywords(
  args,
  kw,
  "|s#s#:urcsign_verify",
  (char **)kwlist,
  (char **)&p,
  &psize,
  (char **)&pk,
  &pksize
 )) return Py_BuildValue("i", -1);
 if (pksize != 32) return Py_BuildValue("i", -1);
 if (urcsign_verify(p,psize,pk) == -1) return Py_BuildValue("i", -1);
 return Py_BuildValue("i", 0);
}

PyObject *pyurcsecretbox_fmt(PyObject *self, PyObject *args, PyObject *kw) {
 unsigned char p[1024];
 char *b;
 char *sk;
 Py_ssize_t bsize = 0;
 Py_ssize_t sksize = 0;
 static const char *kwlist[] = {"b","sk",0};
 if (!PyArg_ParseTupleAndKeywords(
  args,
  kw,
  "|s#s#:urcsecretbox_fmt",
  (char **)kwlist,
  &b,
  &bsize,
  &sk,
  &sksize
 )) return Py_BuildValue("i", -1);
 if (sksize != 32) return Py_BuildValue("i", -1);
 if (bsize > IRC_MTU) return Py_BuildValue("i", -1);
 if (urcsecretbox_fmt(p,b,bsize,sk) == -1) return Py_BuildValue("i", -1);
 return PyBytes_FromStringAndSize((char *)p, 2+12+4+8+bsize+16);
}

PyObject *pyurcsecretbox_open(PyObject *self, PyObject *args, PyObject *kw) {
 unsigned char b[1024];
 char *p;
 char *sk;
 Py_ssize_t psize = 0;
 Py_ssize_t sksize = 0;
 static const char *kwlist[] = {"p","sk",0};
 if (!PyArg_ParseTupleAndKeywords(
  args,
  kw,
  "|s#s#:urcsecretbox_open",
  (char **)kwlist,
  &p,
  &psize,
  &sk,
  &sksize
 )) return Py_BuildValue("i", -1);
 if (sksize != 32) return Py_BuildValue("i", -1);
 if (psize > URC_MTU) return Py_BuildValue("i", -1);
 if (urcsecretbox_open(b,p,psize,sk) == -1) return Py_BuildValue("i", -1);
 return PyBytes_FromStringAndSize((char *)b, -2-12-4-8+psize-16);
}

PyObject *pyurccryptobox_fmt(PyObject *self, PyObject *args, PyObject *kw) {
 unsigned char p[1024];
 char *b;
 char *pk;
 char *sk;
 Py_ssize_t bsize = 0;
 Py_ssize_t pksize = 0;
 Py_ssize_t sksize = 0;
 static const char *kwlist[] = {"b","pk","sk",0};
 if (!PyArg_ParseTupleAndKeywords(
  args,
  kw,
  "|s#s#s#:urccryptobox_fmt",
  (char **)kwlist,
  &b,
  &bsize,
  &pk,
  &pksize,
  &sk,
  &sksize
 )) return Py_BuildValue("i", -1);
 if (pksize != 32) return Py_BuildValue("i", -1);
 if (sksize != 32) return Py_BuildValue("i", -1);
 if (bsize > IRC_MTU) return Py_BuildValue("i", -1);
 if (urccryptobox_fmt(p,b,bsize,pk,sk) == -1) return Py_BuildValue("i", -1);
 return PyBytes_FromStringAndSize((char *)p, 2+12+4+8+bsize+16);
}

PyObject *pyurccryptobox_open(PyObject *self, PyObject *args, PyObject *kw) {
 unsigned char b[1024];
 char *p;
 char *pk;
 char *sk;
 Py_ssize_t psize = 0;
 Py_ssize_t pksize = 0;
 Py_ssize_t sksize = 0;
 static const char *kwlist[] = {"p","pk","sk",0};
 if (!PyArg_ParseTupleAndKeywords(
  args,
  kw,
  "|s#s#s#:urccryptobox_open",
  (char **)kwlist,
  &p,
  &psize,
  &pk,
  &pksize,
  &sk,
  &sksize
 )) return Py_BuildValue("i", -1);
 if (pksize != 32) return Py_BuildValue("i", -1);
 if (sksize != 32) return Py_BuildValue("i", -1);
 if (psize > URC_MTU) return Py_BuildValue("i", -1);
 if (urccryptobox_open(b,p,psize,pk,sk) == -1) return Py_BuildValue("i", -1);
 return PyBytes_FromStringAndSize((char *)b, -2-12-4-8+psize-16);
}

/* ImportError: workaround dummy init function (initliburc) */
PyObject *pyliburc(PyObject *self) { return Py_BuildValue("i", 0); }

static PyMethodDef Module_methods[] = {
 { "liburc",            pyliburc,           METH_NOARGS },
 { "urchub_fmt",        pyurchub_fmt,       METH_VARARGS|METH_KEYWORDS},
 { "urcsign_fmt",       pyurcsign_fmt,      METH_VARARGS|METH_KEYWORDS},
 { "urcsign_verify",    pyurcsign_verify,    METH_VARARGS|METH_KEYWORDS},
 { "urcsecretbox_fmt",  pyurcsecretbox_fmt,  METH_VARARGS|METH_KEYWORDS},
 { "urcsecretbox_open", pyurcsecretbox_open, METH_VARARGS|METH_KEYWORDS},
 { "urccryptobox_fmt",  pyurccryptobox_fmt,  METH_VARARGS|METH_KEYWORDS},
 { "urccryptobox_open", pyurccryptobox_open, METH_VARARGS|METH_KEYWORDS},
 { NULL, NULL}
};

void initliburc(){ (void) Py_InitModule("liburc", Module_methods); }
void initurchub_fmt(){ (void) Py_InitModule("urchub_fmt", Module_methods); }
void initurcsign_fmt(){ (void) Py_InitModule("urcsign_fmt", Module_methods); }
void initurcsign_verify(){ (void) Py_InitModule("urcsign_verify", Module_methods); }
void initurcsecretbox_fmt(){ (void) Py_InitModule("urcsecretbox_fmt", Module_methods); }
void initurcsecretbox_open(){ (void) Py_InitModule("urcsecretbox_open", Module_methods); }
void initurccryptobox_fmt(){ (void) Py_InitModule("urccryptobox_fmt", Module_methods); }
void initurccryptobox_open(){ (void) Py_InitModule("urccryptobox_open", Module_methods); }
