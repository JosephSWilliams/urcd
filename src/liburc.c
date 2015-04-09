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

/* ImportError: workaround dummy init function (initliburc) */
PyObject *pyliburc(PyObject *self) { return Py_BuildValue("i", 0); }

PyObject *pyurc_jail(PyObject *self, PyObject *args, PyObject *kw) {
 char *path;
 Py_ssize_t pathsize = 0;
 static const char *kwlist[] = {"path",0};
 if (!PyArg_ParseTupleAndKeywords(
  args,
  kw,
  "|s#:urc_jail",
  (char **)kwlist,
  &path,
  &pathsize
 )) return Py_BuildValue("i", -1);
 return Py_BuildValue("i", urc_jail(path));
}

PyObject *pyrandombytes(PyObject *self, PyObject *args, PyObject *kw){
 PyObject *bytes;
 unsigned char *b;
 Py_ssize_t n = 0;
 static const char *kwlist[] = {"n",0};
 if (!PyArg_ParseTupleAndKeywords(args, kw,
  #if PY_VERSION_HEX < 0x02050000
   "|i:randombytes",
  #else
   "|n:randombytes",
  #endif
  (char **)kwlist,
  &n
 ))
 return PyBytes_FromStringAndSize("", 0);
 b = PyMem_Malloc(n);
 if (!b) return PyBytes_FromStringAndSize("", 0);
 randombytes(b,n);
 bytes = PyBytes_FromStringAndSize((char *)b, n);
 PyMem_Free(b);
 return bytes;
}

PyObject *pyurchub_fmt(PyObject *self, PyObject *args, PyObject *kw) {
 unsigned char p[1024*2];
 char *b;
 Py_ssize_t psize = 0;
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
 if (urchub_fmt(p,&psize,b,bsize) == -1) return Py_BuildValue("i", -1);
 return PyBytes_FromStringAndSize((char *)p, psize);
}

PyObject *pyurcsign_fmt(PyObject *self, PyObject *args, PyObject *kw) {
 unsigned char p[1024*2];
 char *b;
 char *sk;
 Py_ssize_t psize = 0;
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
 if (urcsign_fmt(p,&psize,b,bsize,sk) == -1) return Py_BuildValue("i", -1);
 return PyBytes_FromStringAndSize((char *)p, psize);
}

PyObject *pyurcsign_verify(PyObject *self, PyObject *args, PyObject *kw) {
 unsigned char *p;
 unsigned char *pk;
 Py_ssize_t psize = 0;
 Py_ssize_t pksize = 0;
 static const char *kwlist[] = {"p", "pk", 0};
 if (!PyArg_ParseTupleAndKeywords(
  args,
  kw,
  "|s#s#:urcsign_verify",
  (char **)kwlist,
  &p,
  &psize,
  &pk,
  &pksize
 )) return Py_BuildValue("i", -1);
 if (pksize != 32) return Py_BuildValue("i", -1);
 if (urcsign_verify(p,psize,pk) == -1) return Py_BuildValue("i", -1);
 return Py_BuildValue("i", 0);
}

PyObject *pyurcsecretbox_fmt(PyObject *self, PyObject *args, PyObject *kw) {
 unsigned char p[1024*2];
 char *b;
 char *sk;
 Py_ssize_t psize = 0;
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
 if (urcsecretbox_fmt(p,&psize,b,bsize,sk) == -1) return Py_BuildValue("i", -1);
 return PyBytes_FromStringAndSize((char *)p, psize);
}

PyObject *pyurcsecretbox_open(PyObject *self, PyObject *args, PyObject *kw) {
 unsigned char b[1024*2];
 char *p;
 char *sk;
 Py_ssize_t bsize = 0;
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
 if (urcsecretbox_open(b,&bsize,p,psize,sk) == -1) return Py_BuildValue("i", -1);
 return PyBytes_FromStringAndSize((char *)b, bsize);
}

PyObject *pyurcsignsecretbox_fmt(PyObject *self, PyObject *args, PyObject *kw) {
 unsigned char p[1024*2];
 char *b;
 char *ssk;
 char *csk;
 Py_ssize_t psize = 0;
 Py_ssize_t bsize = 0;
 Py_ssize_t ssksize = 0;
 Py_ssize_t csksize = 0;
 static const char *kwlist[] = {"b","ssk","csk",0};
 if (!PyArg_ParseTupleAndKeywords(
  args,
  kw,
  "|s#s#s#:urcsignsecretbox_fmt",
  (char **)kwlist,
  &b,
  &bsize,
  &ssk,
  &ssksize,
  &csk,
  &csksize
 )) return Py_BuildValue("i", -1);
 if (ssksize != 64) return Py_BuildValue("i", -1);
 if (csksize != 32) return Py_BuildValue("i", -1);
 if (bsize > IRC_MTU) return Py_BuildValue("i", -1);
 if (urcsignsecretbox_fmt(p,&psize,b,bsize,ssk,csk) == -1) return Py_BuildValue("i", -1);
 return PyBytes_FromStringAndSize((char *)p, psize);
}

PyObject *pyurcsignsecretbox_open(PyObject *self, PyObject *args, PyObject *kw) {
 unsigned char b[1024*2];
 char *p;
 char *csk;
 Py_ssize_t bsize = 0;
 Py_ssize_t psize = 0;
 Py_ssize_t csksize = 0;
 static const char *kwlist[] = {"p","csk",0};
 if (!PyArg_ParseTupleAndKeywords(
  args,
  kw,
  "|s#s#:urcsignsecretbox_open",
  (char **)kwlist,
  &p,
  &psize,
  &csk,
  &csksize
 )) return Py_BuildValue("i", -1);
 if (csksize != 32) return Py_BuildValue("i", -1);
 if (psize > URC_MTU) return Py_BuildValue("i", -1);
 if (urcsignsecretbox_open(b,&bsize,p,psize,csk) == -1) return Py_BuildValue("i", -1);
 return PyBytes_FromStringAndSize((char *)b, bsize);
}

PyObject *pyurcsignsecretbox_verify(PyObject *self, PyObject *args, PyObject *kw) {
 unsigned char *p;
 unsigned char *pk;
 Py_ssize_t psize = 0;
 Py_ssize_t pksize = 0;
 static const char *kwlist[] = {"p", "pk", 0};
 if (!PyArg_ParseTupleAndKeywords(
  args,
  kw,
  "|s#s#:urcsignsecretbox_verify",
  (char **)kwlist,
  &p,
  &psize,
  &pk,
  &pksize
 )) return Py_BuildValue("i", -1);
 if (pksize != 32) return Py_BuildValue("i", -1);
 if (urcsignsecretbox_verify(p,psize,pk) == -1) return Py_BuildValue("i", -1);
 return Py_BuildValue("i", 0);
}

PyObject *pyurccryptobox_fmt(PyObject *self, PyObject *args, PyObject *kw) {
 unsigned char p[1024*2];
 char *b;
 char *pk;
 char *sk;
 Py_ssize_t psize = 0;
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
 if (urccryptobox_fmt(p,&psize,b,bsize,pk,sk) == -1) return Py_BuildValue("i", -1);
 return PyBytes_FromStringAndSize((char *)p, psize);
}

PyObject *pyurccryptobox_open(PyObject *self, PyObject *args, PyObject *kw) {
 unsigned char b[1024*2];
 char *p;
 char *pk;
 char *sk;
 Py_ssize_t bsize = 0;
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
 if (urccryptobox_open(b,&bsize,p,psize,pk,sk) == -1) return Py_BuildValue("i", -1);
 return PyBytes_FromStringAndSize((char *)b, bsize);
}

PyObject *pyurccryptoboxpfs_fmt(PyObject *self, PyObject *args, PyObject *kw) {
 unsigned char p[1024*2];
 char *b;
 char *pk0;
 char *sk0;
 char *pk1;
 char *sk1;
 Py_ssize_t psize = 0;
 Py_ssize_t bsize = 0;
 Py_ssize_t pk0size = 0;
 Py_ssize_t sk0size = 0;
 Py_ssize_t pk1size = 0;
 Py_ssize_t sk1size = 0;
 static const char *kwlist[] = {"b","pk0","sk0","pk1","sk1",0};
 if (!PyArg_ParseTupleAndKeywords(
  args,
  kw,
  "|s#s#s#s#s#:urccryptoboxpfs_fmt",
  (char **)kwlist,
  &b,
  &bsize,
  &pk0,
  &pk0size,
  &sk0,
  &sk0size,
  &pk1,
  &pk1size,
  &sk1,
  &sk1size
 )) return Py_BuildValue("i", -1);
 if (pk0size != 32) return Py_BuildValue("i", -1);
 if (sk0size != 32) return Py_BuildValue("i", -1);
 if (pk1size != 32) return Py_BuildValue("i", -1);
 if (sk1size != 32) return Py_BuildValue("i", -1);
 if (bsize > IRC_MTU) return Py_BuildValue("i", -1);
 if (urccryptoboxpfs_fmt(p,&psize,b,bsize,pk0,sk0,pk1,sk1) == -1) return Py_BuildValue("i", -1);
 return PyBytes_FromStringAndSize((char *)p, psize);
}

PyObject *pyurccryptoboxpfs_open(PyObject *self, PyObject *args, PyObject *kw) {
 unsigned char b[1024*2];
 unsigned char pk0[32];
 unsigned char zk[32];
 char *p;
 char *sk0;
 char *pk1;
 char *sk1;
 Py_ssize_t bsize = 0;
 Py_ssize_t psize = 0;
 Py_ssize_t sk0size = 0;
 Py_ssize_t pk1size = 0;
 Py_ssize_t sk1size = 0;
 static const char *kwlist[] = {"p","sk0","pk1","sk1",0};
 if (!PyArg_ParseTupleAndKeywords(
  args,
  kw,
  "|s#s#s#s#:urccryptoboxpfs_open",
  (char **)kwlist,
  &p,
  &psize,
  &sk0,
  &sk0size,
  &pk1,
  &pk1size,
  &sk1,
  &sk1size
 )) return Py_BuildValue("i", -1);
 if (sk0size != 32) return Py_BuildValue("i", -1);
 if (pk1size != 32) return Py_BuildValue("i", -1);
 if (sk1size != 32) return Py_BuildValue("i", -1);
 if (psize > URC_MTU) return Py_BuildValue("i", -1);
 if (urccryptoboxpfs_open(b,&bsize,p,psize,pk0,sk0,pk1,sk1) == -1) {
  bzero(zk,32);
  if (memcmp(pk0,zk,32)) return Py_BuildValue("OO",
   PyBytes_FromStringAndSize((char *)pk0, 32),
   Py_BuildValue("i", -1)
  );
  return Py_BuildValue("OO",
   Py_BuildValue("i", -1),
   Py_BuildValue("i", -1)
  );
 }
 return Py_BuildValue("OO",
  PyBytes_FromStringAndSize((char *)pk0, 32),
  PyBytes_FromStringAndSize((char *)b, bsize)
 );
}

static PyMethodDef Module_methods[] = {
 { "liburc",                  pyliburc,                  METH_NOARGS },
 { "urc_jail",                pyurc_jail,                METH_VARARGS|METH_KEYWORDS},
 { "randombytes",             pyrandombytes,             METH_VARARGS|METH_KEYWORDS},
 { "urchub_fmt",              pyurchub_fmt,              METH_VARARGS|METH_KEYWORDS},
 { "urcsign_fmt",             pyurcsign_fmt,             METH_VARARGS|METH_KEYWORDS},
 { "urcsign_verify",          pyurcsign_verify,          METH_VARARGS|METH_KEYWORDS},
 { "urcsecretbox_fmt",        pyurcsecretbox_fmt,        METH_VARARGS|METH_KEYWORDS},
 { "urcsecretbox_open",       pyurcsecretbox_open,       METH_VARARGS|METH_KEYWORDS},
 { "urcsignsecretbox_fmt",    pyurcsignsecretbox_fmt,    METH_VARARGS|METH_KEYWORDS},
 { "urcsignsecretbox_open",   pyurcsignsecretbox_open,   METH_VARARGS|METH_KEYWORDS},
 { "urcsignsecretbox_verify", pyurcsignsecretbox_verify, METH_VARARGS|METH_KEYWORDS},
 { "urccryptobox_fmt",        pyurccryptobox_fmt,        METH_VARARGS|METH_KEYWORDS},
 { "urccryptobox_open",       pyurccryptobox_open,       METH_VARARGS|METH_KEYWORDS},
 { "urccryptoboxpfs_fmt",     pyurccryptoboxpfs_fmt,     METH_VARARGS|METH_KEYWORDS},
 { "urccryptoboxpfs_open",    pyurccryptoboxpfs_open,    METH_VARARGS|METH_KEYWORDS},
 { NULL, NULL}
};

void initliburc(){ (void) Py_InitModule("liburc", Module_methods); }
void initurc_jail(){ (void) Py_InitModule("urc_jail", Module_methods); }
void initrandombytes(){ (void) Py_InitModule("randombytes", Module_methods); }
void initurchub_fmt(){ (void) Py_InitModule("urchub_fmt", Module_methods); }
void initurcsign_fmt(){ (void) Py_InitModule("urcsign_fmt", Module_methods); }
void initurcsign_verify(){ (void) Py_InitModule("urcsign_verify", Module_methods); }
void initurcsecretbox_fmt(){ (void) Py_InitModule("urcsecretbox_fmt", Module_methods); }
void initurcsecretbox_open(){ (void) Py_InitModule("urcsecretbox_open", Module_methods); }
void initurccryptobox_fmt(){ (void) Py_InitModule("urccryptobox_fmt", Module_methods); }
void initurccryptobox_open(){ (void) Py_InitModule("urccryptobox_open", Module_methods); }
void initurcsignsecretbox_fmt(){ (void) Py_InitModule("urcsignsecretbox_fmt", Module_methods); }
void initurcsignsecretbox_open(){ (void) Py_InitModule("urcsignsecretbox_open", Module_methods); }
void initurccryptoboxpfs_fmt(){ (void) Py_InitModule("urccryptoboxpfs_fmt", Module_methods); }
void initurccryptoboxpfs_open(){ (void) Py_InitModule("urccryptoboxpfs_open", Module_methods); }
