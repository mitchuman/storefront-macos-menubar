import posthog from 'posthog-js'
import { ROUTES } from '@/lib/env'

const token = process.env.NEXT_PUBLIC_POSTHOG_PROJECT_TOKEN
const isAdminRoute = window.location.pathname.startsWith(`/${ROUTES.studio}`)

if (token && process.env.NODE_ENV !== 'development' && !isAdminRoute) {
	posthog.init(token, {
		api_host: '/sfph',
		ui_host: 'https://us.posthog.com',
		defaults: '2026-05-30',
		capture_exceptions: true,
	})
}
