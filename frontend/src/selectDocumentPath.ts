export function selectDocumentPath(
  currentPath: string | null,
  documents: string[],
): string | null {
  if (currentPath !== null && documents.includes(currentPath)) {
    return currentPath
  }
  return documents[0] ?? null
}
