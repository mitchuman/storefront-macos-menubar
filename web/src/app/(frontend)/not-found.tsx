import type { Metadata } from 'next'
import { groq } from 'next-sanity'
import { draftMode } from 'next/headers'
import ModulesResolver from '@/modules'
import { client } from '@/sanity/lib/client'
import { MODULES_QUERY } from '@/sanity/lib/queries'
import { token } from '@/sanity/lib/token'
import type { NOT_FOUND_QUERY_RESULT } from '@/sanity/types'

export default async function () {
	const page = await getPage()
	return <ModulesResolver page={page} />
}

export async function generateMetadata(): Promise<Metadata> {
	const page = await getPage()

	return {
		title: page?.metadata?.title,
		description: page?.metadata?.description,
		openGraph: {
			title: page?.metadata?.title,
			description: page?.metadata?.description,
		},
		robots: {
			index: page?.metadata?.noIndex ? false : undefined,
		},
	}
}

async function getPage() {
	// Prefer a plain client fetch here — defineLive's sanityFetch returns
	// undefined inside the not-found boundary (after notFound() is thrown).
	const { isEnabled } = await draftMode()

	return await client
		.withConfig({
			token: isEnabled ? token : undefined,
			perspective: isEnabled ? 'drafts' : 'published',
			useCdn: !isEnabled,
			stega: isEnabled,
		})
		.fetch<NOT_FOUND_QUERY_RESULT>(NOT_FOUND_QUERY)
}

const NOT_FOUND_QUERY = groq`
	*[_type == 'page' && metadata.slug.current == '404'][0]{
		...,
		modules[]{ ${MODULES_QUERY} }
	}
`
