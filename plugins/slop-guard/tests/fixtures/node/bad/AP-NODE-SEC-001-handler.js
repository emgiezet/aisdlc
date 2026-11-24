// ruleid: slopguard.node.prototype-pollution-merge
app.post('/admin/config', (req, res) => {
  const config = {};
  for (const key in req.body) {
    config[key] = req.body[key]; // __proto__ key pollutes Object.prototype
  }
  res.json(config);
});

// ruleid: slopguard.node.prototype-pollution-merge
router.put('/settings', (req, res) => {
  for (const key in req.query) {
    settings[key] = req.query[key];
  }
  res.send('ok');
});

// ruleid: slopguard.node.prototype-pollution-merge
app.patch('/profile', async (req, res) => {
  const patch = {};
  for (const key in req.params) {
    patch[key] = req.params[key];
  }
  await User.update(req.user.id, patch);
  res.json(patch);
});
