import { stegaClean } from 'next-sanity'
import { cacheLife } from 'next/cache'
import type { ComponentProps } from 'react'
import { bundledThemes, codeToHtml, splitLines } from 'shiki'
import { cn } from '@/lib/utils'
import type { Code } from '@/sanity/types'
import ClickToCopy from '@/ui/click-to-copy'
import css from './code.module.css'

export default async function ({
	value,
	theme = 'dark-plus',
	className,
}: {
	theme?: keyof typeof bundledThemes
	value?: Code
} & ComponentProps<'article'>) {
	if (!value?.code) return null

	const html = await highlight({
		code: stegaClean(value.code),
		lang: value.language,
		theme,
		highlightedLines: value.highlightedLines,
	})

	const [path, filename] = value.filename?.includes('/')
		? value.filename.split(/(.*)\/(.*)$/).filter(Boolean)
		: [, value.filename]

	return (
		<article
			className={cn('overflow-hidden rounded', className)}
			data-module="code"
		>
			<menu className="text-background gap-ch bg-foreground flex min-h-lh items-center border-b border-current/30 text-sm">
				{value.filename && (
					<li className="line-clamp-1 pl-4 break-all">
						{path && <span className="text-background/50">{path}/</span>}
						<span>{filename}</span>
					</li>
				)}
				<li className="ml-auto shrink-0">
					<ClickToCopy
						value={stegaClean(value.code)}
						className={cn(
							'p-2 text-lg transition-transform not-hover:opacity-50 active:scale-90 [&.copied]:opacity-100',
							!theme.includes('light') && 'text-white',
						)}
					/>
				</li>
			</menu>

			<div
				className={cn(
					css.code,
					'[--highlight-color:var(--color-green-400)] *:p-4',
				)}
				dangerouslySetInnerHTML={{ __html: html }}
			/>
		</article>
	)
}

/**
 * Cached because Shiki reads `Date.now()` internally, which a prerender can't
 * bake in. Highlighting is a pure function of its input, so `cacheLife('max')`
 * is honest and keeps the result in the static shell.
 */
async function highlight({
	code,
	lang,
	theme,
	highlightedLines,
}: {
	code: string
	lang?: string
	theme: keyof typeof bundledThemes
	highlightedLines?: number[]
}) {
	'use cache'
	cacheLife('max')

	return await codeToHtml(code, {
		lang: lang as any,
		theme,
		decorations: highlightedLines
			?.map((row) => ({
				row,
				characters: splitLines(code)[row - 1]?.[0]?.length,
			}))
			?.filter(({ characters }) => characters > 0)
			?.map(({ row, characters }) => ({
				start: { line: row - 1, character: 0 },
				end: { line: row - 1, character: characters },
				properties: { class: 'highlight' },
			})),
	})
}
