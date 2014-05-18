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
    Local EncryptedAttribute read (v=0)                  0.430000   0.000000   0.430000 (  0.428674)
    Local EncryptedAttribute read (v=1)                  0.420000   0.010000   0.430000 (  0.433974)
    Local EncryptedDataBag read                          0.010000   0.000000   0.010000 (  0.011308)
    Remote EncryptedAttribute read (v=0)                 1.510000   0.050000   1.560000 (  1.567265)
    Remote EncryptedAttribute read (v=1)                 1.500000   0.060000   1.560000 (  1.570522)
    Remote EncryptedDataBag read                         0.930000   0.050000   0.980000 (  0.989036)
    Local EncryptedAttribute write (v=0)                 0.060000   0.000000   0.060000 (  0.059326)
    Local EncryptedAttribute write (v=1)                 0.090000   0.000000   0.090000 (  0.090731)
    Local EncryptedDataBag write                         0.020000   0.000000   0.020000 (  0.016910)
    Remote EncryptedAttribute write (v=0)                1.140000   0.080000   1.220000 (  1.218726)
    Remote EncryptedAttribute write (v=1)                1.180000   0.070000   1.250000 (  1.259015)
    Remote EncryptedDataBag write                        2.050000   0.150000   2.200000 (  2.208485)
    Local EncryptedAttribute read/write (v=0)            0.560000   0.010000   0.570000 (  0.569158)
    Local EncryptedAttribute read/write (v=1)            0.570000   0.010000   0.580000 (  0.589196)
    Local EncryptedDataBag read/write                    0.980000   0.050000   1.030000 (  1.044585)
    Remote EncryptedAttribute read/write (v=0)           2.720000   0.130000   2.850000 (  2.859289)
    Remote EncryptedAttribute read/write (v=1)           2.660000   0.130000   2.790000 (  2.813521)
    Remote EncryptedDataBag read/write                   3.110000   0.190000   3.300000 (  3.301053)
    
    Finished in 22 seconds
    18 examples, 0 failures

These benchmarks run 100 passes for each test.

Its sole purpose is to avoid accidentally including code that can be too slow.
