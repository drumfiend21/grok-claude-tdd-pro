// Tiny string-utils module for the grok-claude-tdd-pro harness toy.
// See ../README.md for what's missing and why.

export function slugify(input) {
    return input
        .toLowerCase()
        .replace(/\s+/g, '-')
        .replace(/[^a-z0-9-]/g, '');
}
