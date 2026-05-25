// Tests for examples/string-utils. Designed to ship with 4 passing + 1 failing,
// where the failing case is the "obviously-missing behavior" that the harness's
// Red-Green-Refactor loop is meant to close. See ../README.md.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { slugify } from '../src/string-utils.mjs';

test('slugify lowercases', () => {
    assert.equal(slugify('Hello'), 'hello');
});

test('slugify replaces internal whitespace with hyphens', () => {
    assert.equal(slugify('hello world'), 'hello-world');
});

test('slugify strips non-alphanumeric characters', () => {
    assert.equal(slugify('hello, world!'), 'hello-world');
});

test('slugify on empty string returns empty', () => {
    assert.equal(slugify(''), '');
});

// THE RED TEST — the obviously-missing behavior.
// Currently fails: slugify('  hello world  ') returns '-hello-world-' because
// the function does not trim leading/trailing whitespace before collapsing
// internal whitespace runs. The R-G-R loop fix is one line: add .trim() after
// .toLowerCase(). This test SHOULD remain failing at TICKET-005 commit.
test('slugify trims leading and trailing whitespace', () => {
    assert.equal(slugify('  hello world  '), 'hello-world');
});
