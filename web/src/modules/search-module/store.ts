import { create } from 'zustand'
import type { SEARCH_QUERY_RESULT, SearchModule } from '@/sanity/types'
import { search } from './action'

export const useSearchStore = create<{
	loading: boolean
	setLoading: (loading: boolean) => void
	results: SEARCH_QUERY_RESULT
	setResults: (results: SEARCH_QUERY_RESULT) => void
}>((set) => ({
	loading: false,
	setLoading: (loading) => set({ loading }),
	results: [],
	setResults: (results) => set({ results }),
}))

export async function handleSearch({
	scope = 'all',
	query,
	setLoading,
	setResults,
}: {
	scope: SearchModule['scope']
	query: string
	setLoading: (loading: boolean) => void
	setResults: (results: SEARCH_QUERY_RESULT) => void
}) {
	if (!query) {
		setResults([])
		setLoading(false)
		return
	}

	setLoading(true)

	const results = await search({ scope, query })

	setResults(results)
	setLoading(false)

	return results
}
