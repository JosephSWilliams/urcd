int base16_encode(unsigned char *a, unsigned char *b, int blen)
{

  int i = 0;
  int alen = 0;

  for(i=0;i<blen;++i)
  {

    a[alen] = b[i] >> 4;
    if (a[alen] < 10) a[alen] += 48; else a[alen] += 87;
    ++alen;

    a[alen] = b[i] % 16;
    if (a[alen] < 10) a[alen] += 48; else a[alen] += 87;
    ++alen;

  }

  return alen;

}

int base16_decode(unsigned char *b, unsigned char *a, int alen)
{

  int i = 0;
  int blen = 0;

  for(i=0;i<alen;++i)
  {

    if ((a[i] > 47) && (a[i]<58)) b[blen] = a[i] - 48 << 4;
    else if ((a[i] > 96) && (a[i] < 103)) b[blen] = a[i] - 87 << 4;
    else if ((a[i] > 64) && (a[i] < 71)) b[blen] = a[i] - 55 << 4;
    else return blen;
    if (++i == alen) return blen;

    if ((a[i] > 47) && (a[i]<58)) b[blen] += a[i] - 48;
    else if ((a[i] > 96) && (a[i] < 103)) b[blen] += a[i] - 87;
    else if ((a[i] > 64) && (a[i] < 71)) b[blen] += a[i] - 55;
    else return blen;
    ++blen;

  }

  return blen;

}
