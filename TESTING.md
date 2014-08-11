# Testing

## All the Tests

    $ rake test

## Unit Tests

    $ rake unit

## Integration Tests

    $ rake integration

## Benchmarks

You can run some simple benchmarks, not at all realistic:

    $ rspec spec/benchmark/*
                                                                 user     system      total        real
    Local EncryptedAttribute read (v=0)                  0.410000   0.000000   0.410000 (  0.417956)
    Local EncryptedAttribute read (v=1)                  0.390000   0.010000   0.400000 (  0.398934)
    Local EncryptedAttribute read (v=2)                  0.420000   0.000000   0.420000 (  0.420211)
    Local EncryptedDataBag read                          0.010000   0.000000   0.010000 (  0.011614)
    Remote EncryptedAttribute read (v=0)                 1.480000   0.070000   1.550000 (  1.549856)
    Remote EncryptedAttribute read (v=1)                 1.440000   0.060000   1.500000 (  1.486179)
    Remote EncryptedAttribute read (v=2)                 1.510000   0.060000   1.570000 (  1.561124)
    Remote EncryptedDataBag read                         0.970000   0.060000   1.030000 (  1.012260)
    Local EncryptedAttribute write (v=0)                 0.090000   0.000000   0.090000 (  0.089210)
    Local EncryptedAttribute write (v=1)                 0.090000   0.000000   0.090000 (  0.090442)
    Local EncryptedAttribute write (v=2)                 0.060000   0.000000   0.060000 (  0.055671)
    Local EncryptedDataBag write                         0.000000   0.000000   0.000000 (  0.012315)
    Remote EncryptedAttribute write (v=0)                1.140000   0.050000   1.190000 (  1.179739)
    Remote EncryptedAttribute write (v=1)                1.090000   0.090000   1.180000 (  1.161603)
    Remote EncryptedAttribute write (v=2)                1.120000   0.060000   1.180000 (  1.159668)
    Remote EncryptedDataBag write                        2.080000   0.090000   2.170000 (  2.146914)
    Local EncryptedAttribute read/write (v=0)            0.550000   0.000000   0.550000 (  0.555362)
    Local EncryptedAttribute read/write (v=1)            0.540000   0.010000   0.550000 (  0.550447)
    Local EncryptedAttribute read/write (v=2)            0.570000   0.000000   0.570000 (  0.576107)
    Local EncryptedDataBag read/write                    0.950000   0.050000   1.000000 (  0.979758)
    Remote EncryptedAttribute read/write (v=0)           2.670000   0.100000   2.770000 (  2.746405)
    Remote EncryptedAttribute read/write (v=1)           2.700000   0.090000   2.790000 (  2.758583)
    Remote EncryptedAttribute read/write (v=2)           2.660000   0.110000   2.770000 (  2.752359)
    Remote EncryptedDataBag read/write                   3.030000   0.140000   3.170000 (  3.125538)
    
    Finished in 28.01 seconds
    24 examples, 0 failures

These benchmarks run 100 passes for each test.

Its sole purpose is to avoid accidentally including code that can be too slow.
