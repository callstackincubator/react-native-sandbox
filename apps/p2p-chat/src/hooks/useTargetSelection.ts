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

  // Create a list of all possible targets (friends + potential friends)
  const allPossibleTargets = useMemo(
    () => [
      ...targetOptions, // Current friends
      ...potentialFriends.map(pf => pf.id), // Potential friends
    ],
    [targetOptions, potentialFriends]
  )

  useEffect(() => {
    // Update selected target if current one is no longer available
    if (
      allPossibleTargets.length > 0 &&
      !allPossibleTargets.includes(selectedTarget)
    ) {
      setSelectedTarget(allPossibleTargets[0])
    } else if (allPossibleTargets.length === 0 && selectedTarget) {
      // Keep the selected target even if no options available
      // This allows users to manually type or remember target IDs
    }
  }, [targetOptions, potentialFriends, selectedTarget, allPossibleTargets])

  // Initialize with first available target
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
