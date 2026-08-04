'use server'

import { groq } from 'next-sanity'
import { ROUTES } from '@/lib/env'
import { sanityFetchLive } from '@/sanity/lib/live'
import type { SEARCH_QUERY_RESULT, SearchModule } from '@/sanity/types'

const SCOPE_MAP = {
	'blog posts': 'blog.post',
	pages: 'page',
}

export async function search({
	scope = 'all',
	query,
}: {
	scope: SearchModule['scope']
	query: string
}) {
	const scopeValue = SCOPE_MAP[scope as keyof typeof SCOPE_MAP]

	return await sanityFetchLive<SEARCH_QUERY_RESULT>({
		query: SEARCH_QUERY,
		params: {
			queryMatch: query,
			scope: scope === 'all' ? Object.values(SCOPE_MAP) : [scopeValue],
			blogDir: `/${ROUTES.blog}/`,
		},
	})
}

const SEARCH_QUERY = groq`*[
	_type in $scope
	&& defined(metadata.slug.current)
	&& metadata.noIndex != true
	&& !(metadata.slug.current in ['404'])
	&& @ match text::query($queryMatch)
]{
	_id,
	_type,
	title,
	'slug': select(
		_type == 'blog.post' => $blogDir + metadata.slug.current,
		metadata.slug.current == 'index' => '/',
		'/' + metadata.slug.current
	)
}`
