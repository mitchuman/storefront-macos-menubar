'use client'

import { usePathname } from 'next/navigation'
import {
	Suspense,
	useEffect,
	useState,
	type ComponentProps,
} from 'react'
import { useIsDesktop } from '@/hooks/useMatchMedia'
import { cn } from '@/lib/utils'
import css from './hover-details.module.css'

/**
 * @param safeAreaOnHover - Adds a safe area around the details element to prevent it from closing when the mouse leaves the element
 * @param closeAfterNavigate - Closes the details element after a navigation event
 */
export default function ({
	safeAreaOnHover,
	closeAfterNavigate,
	delay,
	className,
	children,
	...props
}: {
	safeAreaOnHover?: boolean
	closeAfterNavigate?: boolean
	delay?: number
} & ComponentProps<'details'>) {
	const isDesktop = useIsDesktop()
	const [open, setOpen] = useState(false)
	let timeout: NodeJS.Timeout

	const events = isDesktop
		? {
				onMouseEnter: () => {
					if (delay) {
						timeout = setTimeout(() => setOpen(true), delay)
					} else {
						setOpen(true)
					}
				},
				onMouseLeave: () => {
					if (delay) clearTimeout(timeout)
					setOpen(false)
				},
			}
		: {}

	return (
		<details
			className={cn(safeAreaOnHover && css.safearea, className)}
			open={open}
			key={String(open)}
			{...events}
			{...props}
		>
			{closeAfterNavigate && (
				<Suspense fallback={null}>
					<CloseOnNavigate setOpen={setOpen} />
				</Suspense>
			)}
			{children}
		</details>
	)
}

function CloseOnNavigate({
	setOpen,
}: {
	setOpen: (open: boolean) => void
}) {
	const pathname = usePathname()
	useEffect(() => {
		setOpen(false)
	}, [pathname, setOpen])
	return null
}
