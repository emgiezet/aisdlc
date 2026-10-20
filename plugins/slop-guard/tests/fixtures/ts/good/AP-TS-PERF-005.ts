// Good: in-place accumulator mutation — UC-2 (no AP-TS-PERF-005 finding)

interface Item { id: string; value: number }

declare const items: Item[];

// Mutates accumulator in place — O(n) allocations, O(1) new objects per iteration.
const index = items.reduce(
    (acc, x) => { acc[x.id] = x; return acc; },
    {} as Record<string, Item>,
);

export { index };
