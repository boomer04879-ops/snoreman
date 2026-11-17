const { withEntitlementsPlist } = require('@expo/config-plugins');

// Snoreman's notifications are scheduled locally; APNs is unnecessary and
// its entitlement cannot be provisioned by a free Apple personal team.
module.exports = (config) => withEntitlementsPlist(config, (mod) => {
  delete mod.modResults['aps-environment'];
  return mod;
});
