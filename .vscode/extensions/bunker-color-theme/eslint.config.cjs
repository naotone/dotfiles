const jsonc = require("eslint-plugin-jsonc");
const jsoncParser = require("jsonc-eslint-parser");

module.exports = [
	{
		ignores: ["node_modules/**", "pnpm-lock.yaml"],
		files: ["themes/**/*.json", "*.json"],
		languageOptions: {
			parser: jsoncParser
		},
		plugins: {
			jsonc
		},
		rules: {
			...jsonc.configs["recommended-with-json"].rules,
			"jsonc/indent": ["error", "tab"],
			"jsonc/object-curly-spacing": ["error", "never"],
			"jsonc/quote-props": ["error", "always"],
			"jsonc/comma-dangle": ["error", "never"]
		}
	}
];
