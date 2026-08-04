'use client'

import posthog from 'posthog-js'
import { cn } from '@/lib/utils'
import { useBlogIndexStore } from '@/modules/blog-index/store'
import type { BlogCategory } from '@/sanity/types'

export default function ({
	category,
	children,
}: {
	category?: BlogCategory
} & React.ComponentProps<'button'>) {
	const { categoryParam, setCategoryParam } = useBlogIndexStore()
	const slug = category?.slug?.current

	return (
		<button
			className={cn(
				categoryParam === slug || (!categoryParam && !category)
					? 'action'
					: 'ghost',
			)}
			onClick={() => {
				const selectedCategory = categoryParam === slug ? null : (slug ?? null)

				setCategoryParam(selectedCategory)
				posthog.capture('blog_category_filtered', {
					category_slug: selectedCategory ?? 'all',
				})
			}}
		>
			{children || category?.title}
		</button>
	)
}
