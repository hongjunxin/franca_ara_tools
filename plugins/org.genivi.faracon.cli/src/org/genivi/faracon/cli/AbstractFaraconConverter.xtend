package org.genivi.faracon.cli

import java.util.Collection
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.impl.BasicEObjectImpl
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.emf.ecore.util.EcoreUtil
import org.franca.core.framework.IModelContainer
import org.genivi.faracon.logging.BaseWithLogger
import org.genivi.faracon.preferences.Preferences
import org.genivi.faracon.preferences.PreferencesConstants

/**
 * Abstract base class for converters in the Faracon project.
 * Ensures that the abstract methods are called correctly from the public method convert
 */
abstract class AbstractFaraconConverter<SRC extends IModelContainer, TAR extends IModelContainer> extends BaseWithLogger {

	val protected Preferences preferences
	var protected ResourceSet resourceSet

	new() {
		preferences = Preferences.getInstance();
	}

	def void convertFiles(Collection<String> filesToConvert) {
		if (filesToConvert.nullOrEmpty) {
			return
		}
		getLogger().logInfo("Converting " + sourceModelName + " models to " + targetModelName + " models...");
		getLogger().increaseIndentationLevel();

		resourceSet = createResourceSet
		val modelContainers = filesToConvert.loadAllFiles
		resolveProxiesAndCheckRemaining
		val srcToTargetContainer = modelContainers.transform
		srcToTargetContainer.putAllModelsInOneResourceSet
		srcToTargetContainer.saveAllModels

		getLogger().decreaseIndentationLevel();
	}

	def abstract ResourceSet createResourceSet()

	def protected abstract Collection<SRC> loadAllFiles(Collection<String> filesToConvert)

	def protected abstract Collection<Pair<SRC, TAR>> transform(Collection<SRC> containers)

	def protected abstract void putAllModelsInOneResourceSet(Collection<Pair<SRC, TAR>> srcToTargetContainer)

	def protected abstract void saveAllModels(Collection<Pair<SRC, TAR>> srcToTargetContainer)

	def protected abstract String getSourceModelName()

	def protected abstract String getTargetModelName()

	def protected findSourceModelUri(EObject sourceModel) {
		val srcModelUri = sourceModel?.eResource()?.getURI()
		if (srcModelUri === null) {
			logger.logInfo("Cannot find model URI for " + sourceModelName + " " + sourceModel)
			return URI.createFileURI("")
		}
		return srcModelUri
	}

	protected def String getOutputDirPath() {
		var String outputDirectoryPath
		try {
			outputDirectoryPath = preferences.getPreference(PreferencesConstants.P_OUTPUT_DIRECTORY_PATH, "");
		} catch (Preferences.UnknownPreferenceException e) {
			getLogger().logError(e.getMessage());
		}
		if (!outputDirectoryPath.isEmpty()) {
			outputDirectoryPath += "/";
		}
		return outputDirectoryPath
	}

	def int resolveProxiesAndCheckRemaining() {
		EcoreUtil.resolveAll(resourceSet);
		val proxiesAfterResolution = EcoreUtil.ProxyCrossReferencer.find(resourceSet)

		if (!proxiesAfterResolution.empty) {
			val proxiesAfterErrorMsg = proxiesAfterResolution.keySet.map [ eObject |
				if (eObject.eIsProxy && eObject instanceof BasicEObjectImpl) {
					val basicEObject = eObject as BasicEObjectImpl
					return "Cannot find object " + basicEObject.eProxyURI()
				} else {
					return "Cannot find object " + eObject.toString
				}
			].join(System.lineSeparator)
			logger.logError(
				"Cannot resolve all references in the provided " + sourceModelName + " files. Found following " +
					proxiesAfterResolution.size + " remaining unresolved objects " + System.lineSeparator +
					proxiesAfterErrorMsg + System.lineSeparator + "Include the necessary " + sourceModelName +
					" files containing the missing objects into the sources of " + sourceModelName +
					" in order to fix this error"
			)
		}
		return proxiesAfterResolution.size
	}

}
