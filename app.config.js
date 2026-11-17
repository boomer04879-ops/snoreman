// Keep the upstream release configuration intact; isolate only sideload builds.
module.exports = ({ config }) => {
  if (process.env.SIDESTORE_BUILD !== '1') return config;
  const { owner, ...standalone } = config;
  const { eas, ...extra } = config.extra || {};
  return {
    ...standalone,
    extra,
    plugins: [...(config.plugins || []), './plugins/with-sidestore-entitlements'],
    ios: {
      ...config.ios,
      bundleIdentifier: 'org.snoreman.sideload',
      buildNumber: '1',
    },
  };
};
