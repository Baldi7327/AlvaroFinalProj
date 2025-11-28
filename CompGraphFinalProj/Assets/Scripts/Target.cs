using UnityEngine;

public class Target : MonoBehaviour
{
    [SerializeField] private float rotateSpeed;
    void Start()
    {
        
    }
    void Update()
    {
        transform.rotation *= Quaternion.Euler(0f, rotateSpeed * Time.deltaTime, 0f);
    }
}