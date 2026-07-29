/** Always resolves to the latest GitHub release DMG via redirect. */
export const MACOS_DMG_URL =
	'https://github.com/nuotsu/storefront-macos-menubar/releases/latest/download/Storefront.dmg'

export const MACOS_DMG_FILENAME = 'Storefront.dmg'

const RELEASES_API =
	'https://api.github.com/repos/nuotsu/storefront-macos-menubar/releases/latest'

export async function getLatestMacosRelease(): Promise<{ version: string }> {
	try {
		const res = await fetch(RELEASES_API, {
			headers: { Accept: 'application/vnd.github+json' },
			next: { revalidate: 3600 },
		})
		if (!res.ok) return { version: 'unknown' }

		const data = (await res.json()) as { tag_name?: string }
		return { version: data.tag_name || 'unknown' }
	} catch {
		return { version: 'unknown' }
	}
}
