import 'server-only'

// Querying with "sanityFetch" will keep content automatically updated
// Before using it, import and render "<SanityLive />" in your layout, see
// https://github.com/sanity-io/next-sanity#live-content-api for more information.
import { defineLive } from 'next-sanity/live'
import { draftMode } from 'next/headers'
import { dev } from '@/lib/env'
import { apiVersion } from '@/sanity/env'
import { client } from './client'
import { token } from './token'

export const { sanityFetch, SanityLive } = defineLive({
	client: client.withConfig({ apiVersion }),
	serverToken: token,
	browserToken: token,
	// Under `cacheComponents` there is no cookie/draftMode auto-resolution, so an
	// omitted `perspective` or `stega` would silently serve published content
	strict: true,
})

export async function sanityFetchLive<T>(
	args: Omit<Parameters<typeof sanityFetch>[0], 'perspective' | 'stega'>,
) {
	'use cache'

	// Readable inside a cache boundary: draft requests bypass cache entries
	// entirely, so they re-execute against the drafts perspective every time
	const isDraftMode = (await draftMode()).isEnabled

	const { data } = await sanityFetch({
		...args,
		perspective: dev || isDraftMode ? 'drafts' : 'published',
		stega: isDraftMode,
	})

	return data as T
}
