'use client'

import { usePathname } from 'next/navigation'
import { Suspense, useEffect, useRef, type ComponentProps } from 'react'

export default function ({ children, ...props }: ComponentProps<'header'>) {
	const ref = useRef<HTMLDivElement>(null)

	// set --header-height
	useEffect(() => {
		if (typeof window === 'undefined') return

		function setHeight() {
			if (!ref.current) return
			document.documentElement.style.setProperty(
				'--header-height',
				`${ref.current.offsetHeight ?? 0}px`,
			)
		}
		setHeight()
		window.addEventListener('resize', setHeight)

		return () => window.removeEventListener('resize', setHeight)
	}, [])

	return (
		<header ref={ref} role="banner" {...props}>
			{children}
			{/* usePathname suspends on dynamic routes — isolate so the header shell can prerender */}
			<Suspense fallback={null}>
				<CloseMenusOnNavigate containerRef={ref} />
			</Suspense>
		</header>
	)
}

function CloseMenusOnNavigate({
	containerRef,
}: {
	containerRef: React.RefObject<HTMLDivElement | null>
}) {
	const pathname = usePathname()

	useEffect(() => {
		if (typeof document === 'undefined') return
		const toggle = document.querySelector('#header-open') as HTMLInputElement
		if (toggle) toggle.checked = false

		if (!containerRef.current) return
		containerRef.current.querySelectorAll('details').forEach((element) => {
			if (element.open) element.open = false
		})
	}, [pathname, containerRef])

	return null
}
