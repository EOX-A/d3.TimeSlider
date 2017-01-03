{
  split, bisect, insort, intersects, distance, merged, after, subtract,
  parseDuration, offsetDate
} = require '../src/utils.coffee'

chai = require 'chai'
chai.should()

describe 'split', ->
  it 'should split a list of integers', ->
    [even, uneven] = split([0, 1, 2, 3], (v) -> (v % 2) == 0)
    even.should.deep.equal([0, 2])
    uneven.should.deep.equal([1, 3])

describe 'bisect', ->
  it 'should provide the correct index', ->
    bisect([0, 1, 3], 2).should.equal(2)

  it 'should provide the correct index with lower bound', ->
    bisect([0, 1], 0).should.equal(1)

  it 'should provide the correct index with lower than lower bound', ->
    bisect([0, 1], -1).should.equal(0)

  it 'should provide the correct index with upper bound', ->
    bisect([0, 1], 1).should.equal(2)

  it 'should provide the correct index with higher than upper bound', ->
    bisect([0, 1], 2).should.equal(2)

describe 'insort', ->
  it 'should add an item at the correct index', ->
    sorted = [0, 1, 3, 4, 5, 6]
    insort(sorted, 2)
    sorted.should.deep.equal([0, 1, 2, 3, 4, 5, 6])

describe 'intersects', ->
  it 'should work with overlapping intervals', ->
    intersects([1, 3], [2, 4]).should.be.true

  it 'should work with overlapping intervals (vice versa)', ->
    intersects([2, 4], [1, 3]).should.be.true

  it 'should work with disjoint intervals', ->
    intersects([1, 2], [3, 4]).should.be.false

  it 'should work with disjoint intervals (vice versa)', ->
    intersects([3, 4], [1, 2]).should.be.false

  it 'should work with adjoining intervals', ->
    intersects([1, 2], [2, 3]).should.be.true

  it 'should work with adjoining intervals', ->
    intersects([2, 3], [1, 2]).should.be.true

describe 'subtract', ->
  it 'should return the original interval when disjoint', ->
    subtract([1, 2], [3, 4]).should.deep.equal([[1, 2]])

  it 'should return the original interval when disjoint', ->
    subtract([1, 2], [3, 4]).should.deep.equal([[1, 2]])

  # TODO

# describe 'parseDuration', ->
#   it 'should work with years', ->
#     parseDuration('P1Y').should.equal(1 * 12 * 30 * 24 * )
