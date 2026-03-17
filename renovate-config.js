module.exports = {
  repositories: [
    process.env.GITHUB_REPOSITORY
  ],

  secrets: {
    INTERNAL_REGISTRY: process.env.INTERNAL_REGISTRY,
    INTERNAL_REGISTRY_CERT: process.env.INTERNAL_REGISTRY_CERT,
    INTERNAL_REGISTRY_KEY: process.env.INTERNAL_REGISTRY_KEY,
    INTERNAL_REGISTRY_CA_CERT: process.env.INTERNAL_REGISTRY_CA_CERT,
  },

  onboarding: false,
  requireConfig: 'optional',
};