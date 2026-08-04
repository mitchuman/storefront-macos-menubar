import { cacheLife } from 'next/cache'
import type { LinkProps } from 'next/link'
import { MACOS_RELEASES_API } from '@/lib/download-macos'
import DownloadMacosLinkClient from './download-macos-link-client'

export default async function (
	props: Omit<LinkProps, 'href'> & React.ComponentProps<'a'>,
) {
	const { version } = await getLatestMacosRelease()
	return <DownloadMacosLinkClient version={version} {...props} />
}

async function getLatestMacosRelease(): Promise<{ version: string }> {
	'use cache'
	cacheLife('hours')

	try {
		const res = await fetch(MACOS_RELEASES_API, {
			headers: { Accept: 'application/vnd.github+json' },
		})
		if (!res.ok) return { version: 'unknown' }

		const data = (await res.json()) as { tag_name?: string }
		return { version: data.tag_name || 'unknown' }
	} catch {
		return { version: 'unknown' }
	}
}
