// ================================================================================================
// 
// If not explicitly stated: Copyright (C) 2018, all rights reserved,
//      R�diger G�bl 
//		Email r.goebl@tum.de
//      Chair for Computer Aided Medical Procedures
//      Technische Universit�t M�nchen
//      Boltzmannstr. 3, 85748 Garching b. M�nchen, Germany
// 
// ================================================================================================

#include "NodeExplorerDataModel.h"

#include <SupraManager.h>

namespace supra
{
	NodeExplorerDataModel::NodeExplorerDataModel(std::string nodeID, std::string nodeType)
		: m_nodeID(nodeID)
		, m_nodeType(nodeType)
	{}
	QString NodeExplorerDataModel::caption() const
	{
		return QString::fromStdString(m_nodeID);
	}
	QString NodeExplorerDataModel::name() const
	{
		return QString::fromStdString(m_nodeType);
	}
	std::unique_ptr<QtNodes::NodeDataModel> NodeExplorerDataModel::clone() const
	{
		std::string newID = SupraManager::Get()->addNode(m_nodeType);
		return std::unique_ptr<NodeDataModel>(new NodeExplorerDataModel(newID, m_nodeType));
	}
	unsigned int NodeExplorerDataModel::nPorts(QtNodes::PortType portType) const
	{
		size_t numPorts = 0;
		auto node = SupraManager::Get()->getNode(m_nodeID);
		if (node)
		{
			switch (portType)
			{
			case QtNodes::PortType::None:
				break;
			case QtNodes::PortType::In:
				numPorts = node->getNumInputs();
				break;
			case QtNodes::PortType::Out:
				numPorts = node->getNumOutputs();
				break;
			default:
				break;
			}
		}
		return static_cast<unsigned int>(numPorts);
	}
	QtNodes::NodeDataType NodeExplorerDataModel::dataType(QtNodes::PortType portType, QtNodes::PortIndex portIndex) const
	{
		return QtNodes::NodeDataType();
	}
	void NodeExplorerDataModel::setInData(std::shared_ptr<QtNodes::NodeData> nodeData, QtNodes::PortIndex port)
	{
	}
	std::shared_ptr<QtNodes::NodeData> NodeExplorerDataModel::outData(QtNodes::PortIndex port)
	{
		return nullptr;
	}
	QWidget * NodeExplorerDataModel::embeddedWidget()
	{
		return nullptr;
		//QLabel * _label;
	}
}
