import { Rng } from "../src/game/rng";
import { generateSet } from "../src/game/generator";

const r = new Rng(482913);
const floats = Array.from({ length: 8 }, () => r.nextFloat());
console.log("FLOATS", JSON.stringify(floats));

const r2 = new Rng(12345);
const ints = Array.from({ length: 8 }, () => r2.nextInt(26));
console.log("INTS", JSON.stringify(ints));

console.log("SET_seed482913", JSON.stringify([0, 1, 2, 3, 4].map((i) => generateSet(482913, i))));
console.log("SET_seed1", JSON.stringify([0, 1, 2].map((i) => generateSet(1, i))));
console.log("SET_seed777", JSON.stringify([0, 1, 2].map((i) => generateSet(777, i))));
