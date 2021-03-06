using UnityEngine;
using UnityEngine.InputSystem;

public class VRInputHandler : MonoBehaviour
{
    public InputActionReference lTrigger = null;
    private float lTriggerValue;

    public InputActionReference rTrigger = null;
    private float rTriggerValue;

    public InputActionReference joystick = null;
    private Vector2 joystickVector;

    public VoxelComputeController voxelComputeController;
    public HeightMapController heightmapComputeController;

    public Transform lHandT;
    public Transform rHandT;

    public PlayerController playerController;

    private void Update()
    {
        lTriggerValue = lTrigger.action.ReadValue<float>();
        rTriggerValue = rTrigger.action.ReadValue<float>();

        joystickVector = joystick.action.ReadValue<Vector2>();

        if (rTriggerValue > 0.2f)
        {
            RaycastHit hitInfo;
            if (Physics.Raycast(rHandT.position, rHandT.forward, out hitInfo, 30f))
            {
                if (voxelComputeController != null && voxelComputeController.enabled)
                {
                    voxelComputeController.fillType = 1;
                    voxelComputeController.EditVoxels(hitInfo);
                }
                if (heightmapComputeController != null && heightmapComputeController.enabled)
                {
                    heightmapComputeController.fillType = 1;
                    heightmapComputeController.EditCells(hitInfo);
                }
            }
        }
        else if (lTriggerValue > 0.2f)
        {
            RaycastHit hitInfo;
            if (Physics.Raycast(lHandT.position, lHandT.forward, out hitInfo, 30f))
            {
                if (voxelComputeController != null && voxelComputeController.enabled)
                {
                    voxelComputeController.fillType = 0;
                    voxelComputeController.EditVoxels(hitInfo);
                }
                if (heightmapComputeController != null && heightmapComputeController.enabled)
                {
                    heightmapComputeController.fillType = 0;
                    heightmapComputeController.EditCells(hitInfo);
                }
            }
        }

        if (joystickVector.x > 0.2 || joystickVector.x < 0.2)
        {
            playerController.Rotate(joystickVector.x);
        }

        playerController.move = joystickVector.y;
    }
}
