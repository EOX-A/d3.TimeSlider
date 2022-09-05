BucketCache = require '../../src/caches/bucket-cache.coffee'
chai = require 'chai'
chai.should()

oneDay = 24 * 60 * 60 * 1000
twoDays = oneDay * 2
threeDays = oneDay * 3

firstDay = new Date('2000-01-01T00:00:00Z')
secondDay = new Date('2000-01-02T00:00:00Z')
thirdDay = new Date('2000-01-03T00:00:00Z')


describe 'BucketCache', ->
  it 'should allow to set and get buckets', ->
    cache = new BucketCache

    # test not set buckets
    cache.hasBucket(oneDay, firstDay).should.be.false
    chai.expect(cache.getBucket(oneDay, firstDay)).to.be.undefined
    cache.getBucketApproximate(oneDay, firstDay).should.deep.equal([0, false])

    # test set buckets
    cache.setBucket(oneDay, firstDay, 5, 4)
    cache.hasBucket(oneDay, firstDay).should.be.true
    cache.getBucket(oneDay, firstDay).should.deep.equal({
      "count": 4
      "offset": 946684800000
      "width": 5
    })
    cache.getBucketApproximate(oneDay, firstDay).should.deep.equal([{
      "count": 4
      "offset": 946684800000
      "width": 5
    }, true])

  it 'should allow to reserve buckets', ->
    cache = new BucketCache

    cache.reserveBucket(oneDay, firstDay)
    cache.isBucketReserved(oneDay, firstDay).should.be.true
    cache.isBucketReserved(oneDay, secondDay).should.be.false

  it 'should correctly approximate', ->
    cache = new BucketCache
    cache.setBucket(twoDays, firstDay, 20, 4)
    cache.getBucketApproximate(oneDay, firstDay).should.deep.equal([2, false])
    cache.getBucketApproximate(oneDay, secondDay).should.deep.equal([2, false])
    cache.getBucketApproximate(oneDay, thirdDay).should.deep.equal([0, false])
