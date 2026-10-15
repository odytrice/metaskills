const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const assets = path.join(__dirname, '..', 'skills', 'paper-doc', 'assets', 'template');
const sandbox = { window: {} };
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(assets, 'c4.js'), 'utf8'), sandbox);
vm.runInContext(fs.readFileSync(path.join(assets, 'model.js'), 'utf8'), sandbox);
const Diagram = sandbox.window.C4Diagram;
const freshModel = () => JSON.parse(JSON.stringify(sandbox.window.PAPER_DOC_MODELS.example));
function diagramAt(viewId, supporting = false) {
  const diagram = Object.create(Diagram.prototype);
  Object.assign(diagram, { m: freshModel(), viewId, showSupporting: supporting, forced: new Set() });
  return diagram;
}

test('the reference model is valid and hidden components roll up at C1', () => {
  const diagram = diagramAt('context');
  Diagram.validate(diagram.m);
  const edges = diagram.deriveEdges(diagram.visibleSet());
  assert.equal(edges.get('service>mail').implied, true);
  assert.equal(edges.get('service>mail').rels[0].from, 'notifier');
  assert.equal(edges.has('api>database'), false, 'internal edges should disappear inside the system');
  assert.equal(edges.get('analyst>service').implied, false, 'explicit context label takes precedence');
});

test('supporting systems can be revealed without changing model identity', () => {
  const diagram = diagramAt('context');
  assert.equal(diagram.visibleSet().has('telemetry'), false);
  diagram.showSupporting = true;
  assert.equal(diagram.deriveEdges(diagram.visibleSet()).has('service>telemetry'), true);
  diagram.showSupporting = false;
  diagram.forced.add('telemetry');
  assert.equal(diagram.visibleSet().has('telemetry'), true, 'flow-forced nodes remain visible');
});

test('container view aggregates worker internals and preserves their detail', () => {
  const diagram = diagramAt('containers');
  const edges = diagram.deriveEdges(diagram.visibleSet());
  const edge = edges.get('worker>database');
  assert.equal(edge.rels.length, 2);
  assert.equal(edge.implied, true);
  assert.equal(edge.async, false, 'a mixed group is not incorrectly described as all async');
  assert.equal(edges.has('analyst>browser'), true);
  assert.equal(edges.has('analyst>service'), false, 'only-view restrictions must be respected');
});

test('component view keeps its boundary and excludes outside-only relations', () => {
  const diagram = diagramAt('worker_components');
  const edges = diagram.deriveEdges(diagram.visibleSet());
  assert.equal(edges.has('claim>renderer'), true);
  assert.equal(edges.has('notifier>mail'), true);
  assert.equal(edges.has('browser>api'), false);
  diagram.vis = diagram.visibleSet();
  assert.equal(diagram.hasTag('renderer', 'async'), true);
  assert.equal(diagram.hasTag('mail', 'data'), false);
});

test('invalid parent and view cycles fail before rendering', () => {
  let model = freshModel();
  model.elements.service.parent = 'api';
  assert.throws(() => Diagram.validate(model), /cycle/);
  model = freshModel();
  model.views.context.parent = 'containers';
  assert.throws(() => Diagram.validate(model), /cycle/);
  model = freshModel();
  model.elements.api.parent = 'missing';
  assert.throws(() => Diagram.validate(model), /missing parent/);
});

test('invalid relationship references and invisible flow endpoints fail clearly', () => {
  let model = freshModel();
  model.rels[0].to = 'missing';
  assert.throws(() => Diagram.validate(model), /valid endpoints/);
  model = freshModel();
  model.flows[0].steps[0].view = 'worker_components';
  assert.throws(() => Diagram.validate(model), /not represented/);
  model = freshModel();
  model.views.containers.layout.api[0] = NaN;
  assert.throws(() => Diagram.validate(model), /invalid layout/);
});

test('DSL exports hierarchy and static view membership with escaped values', () => {
  const diagram = diagramAt('context');
  diagram.m.name = 'Report "Example"\nDraft';
  const dsl = diagram.toDSL();
  assert.ok(dsl.startsWith('workspace ' + JSON.stringify(diagram.m.name) + ' '));
  assert.match(dsl, /service = softwareSystem/);
  assert.match(dsl, /worker = container/);
  assert.match(dsl, /claim = component/);
  assert.match(dsl, /include analyst service mail telemetry/);
  assert.match(dsl, /component worker "worker_components"/);
  assert.doesNotMatch(dsl, /interview prep|Saldo Vista|ORANGE_MODEL/);
});
