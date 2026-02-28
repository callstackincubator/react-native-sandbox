import {useEffect, useMemo, useState} from 'react'

import {PotentialFriend} from '../types'

interface UseTargetSelectionProps {
  targetOptions: string[]
  potentialFriends: PotentialFriend[]
}

export const useTargetSelection = ({
  targetOptions,
  potentialFriends,
}: UseTargetSelectionProps) => {
  const [selectedTarget, setSelectedTarget] = useState<string>('')

  const allPossibleTargets = useMemo(
    () => [...targetOptions, ...potentialFriends.map(pf => pf.id)],
    [targetOptions, potentialFriends]
  )

  useEffect(() => {
    if (
      allPossibleTargets.length > 0 &&
      !allPossibleTargets.includes(selectedTarget)
    ) {
      setSelectedTarget(allPossibleTargets[0])
    }
  }, [targetOptions, potentialFriends, selectedTarget, allPossibleTargets])

  useEffect(() => {
    if (!selectedTarget && allPossibleTargets.length > 0) {
      setSelectedTarget(allPossibleTargets[0])
    }
  }, [allPossibleTargets, selectedTarget])

  return {
    selectedTarget,
    setSelectedTarget,
    allPossibleTargets,
  }
}
