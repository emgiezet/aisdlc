// Bad: O(n²) reduce accumulator spreading — triggers AP-TS-PERF-005
//   UC-1: no-reduce-accumulator-copy

interface Item { id: string; value: number }

declare const items: Item[];

// Spreads the entire accumulator on every iteration — O(n²) allocations.
const index = items.reduce(
    (acc, x) => ({ ...acc, [x.id]: x }),
    {} as Record<string, Item>,
);

export { index };
