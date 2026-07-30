import posthog from 'posthog-js'

const token = process.env.NEXT_PUBLIC_POSTHOG_PROJECT_TOKEN

if (token && process.env.NODE_ENV !== 'development') {
	posthog.init(token, {
		api_host: '/sfph',
		ui_host: 'https://us.posthog.com',
		defaults: '2026-05-30',
		capture_exceptions: true,
	})
}
