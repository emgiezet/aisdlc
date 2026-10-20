# AP-TS-PERF-005 — O(n²) reduce accumulator spreading

**Category:** performance | **Severity:** warn
**Frameworks:** [plain]

## Summary
Spreading the accumulator on every reduce iteration creates a new object at each step, making the whole operation O(n²) in both time and memory allocations. The accumulated result from all previous iterations is copied on each call. Mutate the accumulator in place instead and return it; total allocation becomes O(1) objects rather than O(n).

## Do Not Write
```typescript
const index = items.reduce((acc, x) => ({ ...acc, [x.id]: x }), {} as Record<string, Item>);
```

## Instead Write
```typescript
const index = items.reduce((acc, x) => { acc[x.id] = x; return acc; }, {} as Record<string, Item>);
```

