const test = require("node:test");
const assert = require("node:assert");
const {deliveryFee, resolveOptions, priceCart} = require("./pricing");

const burger = {
  name: "Burger", sale_price: 2500, price: 2500, quantity: 10, on_sale: true,
  options: [
    {name: "Taille", required: true, max: 1, choices: [
      {label: "Normal", price: 0}, {label: "Maxi", price: 1000}]},
    {name: "Suppléments", required: false, max: 2, choices: [
      {label: "Fromage", price: 300}, {label: "Œuf", price: 200},
      {label: "Bacon", price: 500, stock: 0}]},
  ],
};

test("frais de livraison identiques à l'application", () => {
  assert.equal(deliveryFee("Bacongo"), 1000);
  assert.equal(deliveryFee("Talangaï"), 1500);
  assert.equal(deliveryFee("Kintélé"), 2000);
  assert.equal(deliveryFee("Kombé"), 2500);
  assert.equal(deliveryFee(""), 1000);
});

test("options relues et suppléments recalculés", () => {
  const r = resolveOptions("Taille : Maxi · Suppléments : Fromage, Œuf",
      burger.options);
  assert.equal(r.extra, 1500);
  assert.match(resolveOptions("Suppléments : Fromage", burger.options).error,
      /obligatoire/);
  assert.match(resolveOptions("Taille : Géant", burger.options).error,
      /inconnu/);
});

test("montant calculé par le serveur, pas par le téléphone", () => {
  const r = priceCart([{quantity: 2,
    options: "Taille : Maxi · Suppléments : Fromage", product: burger}],
  "Talangaï");
  assert.deepEqual(r.errors, []);
  assert.equal(r.subtotal, (2500 + 1000 + 300) * 2);
  assert.equal(r.total, r.subtotal + 1500);
});

test("contrôles : stock, variante épuisée, ordonnance, hors vente", () => {
  const r = priceCart([
    {quantity: 11, options: "Taille : Normal", product: burger},
    {quantity: 1, options: "Taille : Normal · Suppléments : Bacon",
      product: burger},
    {quantity: 1, options: "", product: {name: "Amoxicilline",
      sale_price: 3000, quantity: 5, requires_prescription: true}},
    {quantity: 1, options: "", product: {name: "Ancien", sale_price: 100,
      quantity: 5, on_sale: false}},
  ], "Bacongo");
  assert.equal(r.errors.length, 4);
});

test("ancien produit sans options ni champ on_sale", () => {
  const r = priceCart([{quantity: 1, options: "",
    product: {name: "Chemise", sale_price: 3500, price: 3500, quantity: 3}}],
  "Bacongo");
  assert.deepEqual(r.errors, []);
  assert.equal(r.total, 4500);
});
